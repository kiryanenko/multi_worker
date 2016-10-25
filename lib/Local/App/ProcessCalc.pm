package Local::App::ProcessCalc;

use strict;
use warnings;
use JSON::XS;
use IO::Socket;
 
our $VERSION = '1.0';

our $status_file = './calc_status.txt';

#Определение обрабатываемых сигналов
$SIG{CHLD} = sub {
	while( my $pid = waitpid(-1, WNOHANG)){
		last if $pid == -1;
		if( WIFEXITED($?) ){
			my $status = $? >> 8;
			print "$pid exit with status $status $/";
		}
		else { print "Process $pid sleep $/" }
	}
};

sub change_status {
	my $pid = shift;
	my $status = shift;
	
	my $struct = \{};
	if (open(my $fh, '<', $status_file)) {
  		my $json = <$fh>;
    	my $decode_json = JSON::XS::decode_json($json);
		$struct = $decode_json if defined $decode_json;
		close $fh;
	}
	open(my $fh, '>', $status_file) or die "Не могу открыть > $status_file";
	$struct->{$pid}->{cnt} = 0 unless exists $struct->{$pid};
	$struct->{$pid}->{status} = $status;
	$struct->{$pid}->{cnt}++ if $status eq 'DONE';
	print $fh $struct;
	close $fh;
}

sub multi_calc {
    # На вход получаем 3 параметра
    my $fork_cnt = shift;  # кол-во паралельных потоков в котором мы будем обрабатывать задания
    my $jobs_pack = shift; # пул заданий
    my $calc_port = shift; # порт на котором доступен сетевой калькулятор

	my @jobs = unpack 'L(L/a*)*', $jobs_pack;
    # расчитываем сколько заданий приходится на 1 обработчик
    my $cnt = shift @jobs;
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
    		change_status($pid, 'READY');
    		push @pids, $pid;
    	} else {
    		die "Cannot fork $!" unless defined $proc;
    		
    		my $socket = IO::Socket::INET->new(
				PeerAddr => 'localhost',
				PeerPort => $calc_port,
				Proto => "tcp",
				Type => SOCK_STREAM
			) or die "Can`t connect $/";
			
    		for (my $j = $i * $cnt_per_proc; $j < $i * ($cnt_per_proc + 1) && $j < $cnt; $j++) {
    			change_status($$, 'PROCESS');
    			$job = pack 'L/a*', $jobs[$j];
    			print $socket $job;
				my $answer = <$socket>;
				print(join($/, @answer));
    			change_status($$, 'DONE');
    		}
    		exit;
    	}
    }
    for (@pids) { waitpid($_, 0); }
    my $hashref = retrieve($status_file);
    die "Не удалось открыть $status_file" unless defined $hashref;
    my $ret = [];
    
    # Возвращаем массив всех обработанных заданий
    return $res;
}


sub get_from_server {
    # Функция получающая набор заданий с сервера
    # На вход получаем порт, который слушает сервер, и кол-во заданий которое надо вернуть
    my $port = shift;
    my $limit = shift;
    # Создаём подключение к серверу
    # Отправляем 2-х байтный int (кол-во сообщений которое мы от него просим)
    # Получаем 4-х байтный int + последовательной сообщений состоящих их 4-х байтных интов + строк указанной длинны
    my $ret = [];
    # Возвращаем ссылку на массив заданий
    return $ret;
}

sub ceil($) { 
  	my $x = shift;
	return int($x) < $x ? int($x)+1 : $x
}

1;
