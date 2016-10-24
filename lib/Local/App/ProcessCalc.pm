package Local::App::ProcessCalc;

use strict;
use warnings;

our $VERSION = '1.0';

our $status_file = './calc_status.txt';

#Определение обрабатываемых сигналов
$SIG{...} = \&...;

sub multi_calc {
    # На вход получаем 3 параметра
    my $fork_cnt = shift;  # кол-во паралельных потоков в котором мы будем обрабатывать задания
    my $jobs_pack = shift; # пул заданий
    my $calc_port = shift; # порт на котором доступен сетевой калькулятор

	my @jobs = 'L(L/a*)*';
    # расчитываем сколько заданий приходится на 1 обработчик
    my $cnt = shift @jobs;
    my $cnt_per_proc = ceil($cnt / $fork_cnt);
    # запускаем необходимое кол-во процессов
    # в каждом процессе идём по необходимым примерам, отправляем в сервер, который умеет их обрабатывать, результат записываем в файл
    # после каждого расчета, обновляем своё состояние в файле статуса $status_file (файл должен быть удалён после завершения программы, а не функции)
    # в файле статусе должены храниться структура {PID => {status => 'READY|PROCESS|DONE', cnt => $cnt}}, где $cnt - кол-во обработанных заданий этим обработчиком
    # в рамках одного обработчика делаем одно соединение с сервером обработки заданий, а в рамках этого соединение обрабатываем все задания
    # Исходящее и входящее сообщение имеет одинаковый формат 4-х байтовый инт + строка указанной длинны
    
    
    
    for (my $i = 0; $i < $fork_cnt && $i < $cnt; $i++) {
    	unless (my $proc = fork()) {
    		die "Cannot fork $!" unless defined $proc; 
    		for (my $j = $i * $cnt_per_proc; $j < $i * ($cnt_per_proc + 1) && 
    			$j < $cnt; $j++) {
    			
    		}
    		exit;
    	}
    	
    }
    
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
