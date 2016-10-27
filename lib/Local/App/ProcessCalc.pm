package Local::App::ProcessCalc;

use strict;
use warnings;
use JSON::XS;
use IO::Socket;
 
our $VERSION = '1.0';

our $status_file = './calc_status.txt';
my $result_file = './results.txt';

#Определение обрабатываемых сигналов
$SIG{INT} = sub {
	unlink($status_file);
	exit;
};

sub change_status {
	my $pid = shift;
	my $status = shift;
	
	my $struct = {};
	if (open(my $fh, '<', $status_file)) {
		# Считываю структуру из status_file
  		my $json = <$fh>;
    	my $decode_json = JSON::XS::decode_json($json);
		$struct = $decode_json if defined $decode_json;
		close $fh;
	}
	# Перезаписываю структуру в status_file
	open(my $fh, '>', $status_file) or die "Не могу открыть > $status_file";
	$struct->{$pid} = { cnt => 0 } unless exists $struct->{$pid};
	$struct->{$pid}{status} = $status;
	$struct->{$pid}{cnt}++ if $status eq 'done';
	print $fh JSON::XS::encode_json($struct);
	close $fh;
}

sub multi_calc {
    # На вход получаем 3 параметра
    my $fork_cnt = shift;  # кол-во паралельных потоков в котором мы будем обрабатывать задания
    my $jobs = shift; # пул заданий
    my $calc_port = shift; # порт на котором доступен сетевой калькулятор
    # расчитываем сколько заданий приходится на 1 обработчик
    my $cnt = scalar @$jobs;
    my $cnt_per_proc = ceil($cnt / $fork_cnt);
    # запускаем необходимое кол-во процессов
    # в каждом процессе идём по необходимым примерам, отправляем в сервер, который умеет их обрабатывать, результат записываем в файл
    # после каждого расчета, обновляем своё состояние в файле статуса $status_file (файл должен быть удалён после завершения программы, а не функции)
    # в файле статусе должены храниться структура {PID => {status => 'READY|PROCESS|DONE', cnt => $cnt}}, где $cnt - кол-во обработанных заданий этим обработчиком
    # в рамках одного обработчика делаем одно соединение с сервером обработки заданий, а в рамках этого соединение обрабатываем все задания
    # Исходящее и входящее сообщение имеет одинаковый формат 4-х байтовый инт + строка указанной длинны
    
    unlink($status_file);	# Удаляю status_file
    # change_status будет происходить в родительском процессе, т.к. в change_status 2 раза открывается файл, из-за этого нет гарантии, что файл не изменится между этими открытиями. Для этого связываю родительский и дочерние потоки
    my ($r, $w);
    pipe($r, $w);
    my @pids;
    for (my $i = 0; $i < $fork_cnt && $i < $cnt; $i++) {
    	if (my $pid = fork()) {
    		push @pids, $pid;
    	} else {
    		die "Cannot fork $!" unless defined $pid;
    		# Дочерний процесс
    		close($r);
    		syswrite($w, pack('SS/a*', $$, 'READY'));	# Передаю статус
    		my $socket = IO::Socket::INET->new(			# Подключаюсь к серверу calc
				PeerAddr => 'localhost',
				PeerPort => $calc_port,
				Proto => "tcp",
				Type => SOCK_STREAM
			) or die "Can`t connect $/";
			
    		for (my $j = $i * $cnt_per_proc; ($j < $cnt_per_proc * ($i + 1)) && ($j < $cnt); $j++) {
    			syswrite($w, pack('SS/a*', $$, 'PROCESS'));		# Передаю статус
    			syswrite($socket, pack('L/a*', @$jobs[$j]));	# Отправляю задачу на серв calc
    			# Получаю ответ
    			my $answer;
    			die "Не могу прочесть размер сообщения" unless sysread($socket, $answer, 4) == 4;
				my $len = unpack 'L', $answer;
				die "Не могу прочесть сообщение" unless sysread($socket, $answer, $len) == $len;	
				# Записываю результат в файл	
				open(my $fh, ">>", $result_file) or die "Can't open >> $result_file: $!";
			    syswrite($fh, pack('SL/a*', $j, $answer));
			    close($fh);
			    
    			syswrite($w, pack('SS/a*', $$, 'done'));		# Передаю статус
    		}
    		close($w);
    		exit;
    	}
    }
    close($w);
    # Родитель считывает статусы детей
    my $msg;
    while (sysread($r, $msg, 2) == 2) {
    	my $pid = unpack 'S', $msg;
    	die "Не могу прочесть размер статуса" unless sysread($r, $msg, 2) == 2;
		my $len = unpack 'S', $msg;
		die "Не могу прочесть статус" unless sysread($r, $msg, $len) == $len;
		change_status($pid, $msg);
    }
    close($r);
    for (@pids) { waitpid($_, 0); }
    
    my $res = [];
    open(my $fh, "<", $result_file) or die "Can't open < $result_file: $!";
    while(!eof($fh)) {
    	my $msg;
    	die "Не могу прочесть номер задания" unless read($fh, $msg, 2) == 2;
    	my $j = unpack 'S', $msg;
    	die "Не могу прочесть размер сообщения" unless read($fh, $msg, 4) == 4;
		my $len = unpack 'L', $msg;
		die "Не могу прочесть сообщение" unless read($fh, $msg, $len) == $len;
		@$res[$j] = $msg;
    }
    close($fh);
    unlink($result_file);
    # Возвращаем массив всех обработанных заданий
    return $res;
}


sub get_from_server {
    # Функция получающая набор заданий с сервера
    # На вход получаем порт, который слушает сервер, и кол-во заданий которое надо вернуть
    my $port = shift;
    my $limit = shift;
    # Создаём подключение к серверу
    my $socket = IO::Socket::INET->new(
		PeerAddr => 'localhost',
		PeerPort => $port,
		Proto => "tcp",
		Type => SOCK_STREAM
	) or die "Can`t connect $!";
    # Отправляем 2-х байтный int (кол-во сообщений которое мы от него просим)
    my $ret = [];
	syswrite($socket, pack('S', $limit), 2);
	# Получаем 4-х байтный int + последовательной сообщений состоящих их 4-х байтных интов + строк указанной длинны
	my $msg;
	die "Не могу прочесть количество сообщений" unless sysread($socket, $msg, 4) == 4;
	my $cnt = unpack 'S', $msg;
	for (my $i = 0; $i < $cnt; $i++) {
    	die "Не могу прочесть размер сообщения" unless sysread($socket, $msg, 4) == 4;
		my $len = unpack 'L', $msg;
		die "Не могу прочесть сообщение" unless sysread($socket, $msg, $len) == $len;
		push @$ret, $msg;
	}
    # Возвращаем ссылку на массив заданий
    return $ret;
}

sub ceil($) { 
  	my $x = shift;
	return int($x) < $x ? int($x)+1 : $x
}

1;
