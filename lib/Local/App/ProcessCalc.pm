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
  		my $json = <$fh>;
use DDP;
p $json;
    	my $decode_json = JSON::XS::decode_json($json);
		$struct = $decode_json if defined $decode_json;
		close $fh;
	}
	open(my $fh, '>', $status_file) or die "Не могу открыть > $status_file";
	$struct->{$pid} = { cnt => 0 } unless exists $struct->{$pid};
	$struct->{$pid}{status} = $status;
	$struct->{$pid}{cnt}++ if $status eq 'DONE';
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
    
    my @pids;
    for (my $i = 0; $i < $fork_cnt && $i < $cnt; $i++) {
    	if (my $pid = fork()) {    		
    		push @pids, $pid;
    	} else {
    		die "Cannot fork $!" unless defined $pid;
    		
    		change_status($$, 'READY');
    		my $socket = IO::Socket::INET->new(
				PeerAddr => 'localhost',
				PeerPort => $calc_port,
				Proto => "tcp",
				Type => SOCK_STREAM
			) or die "Can`t connect $/";
			
    		for (my $j = $i * $cnt_per_proc; ($j < $cnt_per_proc * ($i + 1)) && ($j < $cnt); $j++) {
    			change_status($$, 'PROCESS');
    			my $job = pack 'L/a*', @$jobs[$j];
    			syswrite($socket, $job);
    			my $answer;
    			die "Не могу прочесть размер сообщения" unless sysread($socket, $answer, 4) == 4;
				my $len = unpack 'L', $answer;
				die "Не могу прочесть сообщение" unless sysread($socket, $answer, $len) == $len;			open(my $fh, ">>", $result_file) or die "Can't open >> $result_file: $!";
			    print $fh pack('SL/a*', $j, $answer);
			    close($fh);
    			change_status($$, 'DONE');
    		}
    		print $socket 'END';
    		exit;
    	}
    }
    for (@pids) { waitpid($_, 0); }
    
    my $res = [];
    open(my $fh, "<", $result_file) or die "Can't open < $result_file: $!";
    while(!eof($fh)) {
    	my $msg;
    	die "Не могу прочесть номер задания" unless sysread($fh, $msg, 2) == 2;
    	my $j = unpack 'S', $msg;
    	die "Не могу прочесть размер сообщения" unless sysread($fh, $msg, 4) == 4;
		my $len = unpack 'L', $msg;
		die "Не могу прочесть сообщение" unless sysread($fh, $msg, $len) == $len;
		@$res[$j] = unpack('a*', $msg);
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
use DDP; 
p $port;
    # Создаём подключение к серверу
    my $socket = IO::Socket::INET->new(
		PeerAddr => 'localhost',
		PeerPort => $port,
		Proto => "tcp",
		Type => SOCK_STREAM
	) or die "Can`t connect $!";
    # Отправляем 2-х байтный int (кол-во сообщений которое мы от него просим)
    # Получаем 4-х байтный int + последовательной сообщений состоящих их 4-х байтных интов + строк указанной длинны
    my $ret = [];
	syswrite($socket, pack('S', $limit), 2);
	my $msg;
	die "Не могу прочесть количество сообщений" unless sysread($socket, $msg, 4) == 4;
	my $cnt = unpack 'S', $msg;
	for (my $i = 0; $i < $cnt; $i++) {
    	die "Не могу прочесть размер сообщения" unless sysread($socket, $msg, 4) == 4;
		my $len = unpack 'L', $msg;
		die "Не могу прочесть сообщение" unless sysread($socket, $msg, $len) == $len;
		push @$ret, unpack('a*', $msg);
	}
    # Возвращаем ссылку на массив заданий
    return $ret;
}

sub ceil($) { 
  	my $x = shift;
	return int($x) < $x ? int($x)+1 : $x
}

1;
