package Local::App::GenCalc;

use strict;
use IO::Socket;
use Time::HiRes qw/alarm/;

my $file_path = './calcs.txt';

sub new_one {
    # Функция вызывается по таймеру каждые 100
    my $new_row = join $/, int(rand(5)).' + '.int(rand(5)), 
                  int(rand(2)).' + '.int(rand(5)).' * '.int(int(rand(10))), 
                  '('.int(rand(10)).' + '.int(rand(8)).') * '.int(rand(7)), 
                  int(rand(5)).' + '.int(rand(6)).' * '.int(rand(8)).' ^ '.int(rand(12)), 
                  int(rand(20)).' + '.int(rand(40)).' * '.int(rand(45)).' ^ '.int(rand(12)), 
                  (int(rand(12))/(int(rand(17))+1)).' * ('.(int(rand(14))/(int(rand(30))+1)).' - '.int(rand(10)).') / '.rand(10).'.0 ^ 0.'.int(rand(6)),  
                  int(rand(8)).' + 0.'.int(rand(10)), 
                  int(rand(10)).' + .5',
                  int(rand(10)).' + .5e0',
                  int(rand(10)).' + .5e1',
                  int(rand(10)).' + .5e+1', 
                  int(rand(10)).' + .5e-1', 
                  int(rand(10)).' + .5e+1 * 2';
    # Далее происходить запись в файл очередь
    
    open(my $fh, ">>", $file_path) or die "Can't open >> $file_path: $!";
    print $fh $new_row;
    close($fh);
    return;
}

#Определение обрабатываемых сигналов
$SIG{ALRM} = sub {
    new_one();
};

sub start_server {
    # На вход приходит номер порта который будет слушат сервер для обработки запросов на получение данных
    my $port = shift;
    # Создание сервера и обработка входящих соединений, форки не нужны 
    # Входящее сообщение это 2-х байтовый инт (кол-во сообщений которое надо отдать в ответ)
    # Исходящее сообщение: ROWS_CNT ROW; ROW := ROW [ROW]; ROW := LEN MESS; LEN - 4-х байтовый инт; MESS - сообщение указанной длины
    
    my $server = IO::Socket::INET->new(
		LocalPort => $port,
		Type      => SOCK_STREAM,
		ReuseAddr => 1,
		Listen    => 10
	) or die "Can't create server on port $port : $@ $/";

	new_one();
	alarm(0.1);
	while(1) {
		if (my $client = $server->accept()) {
			alarm(0);
			my $msg_len;
			if (sysread($client, $msg_len, 2) == 2) {
				my $limit = unpack 'S', $msg_len;
				my $ex = get($limit);
				syswrite($client, pack('L(L/a*)*', scalar(@$ex), @$ex));
			}
			close( $client );
			
		}
		alarm(0.1);
	}
	close( $server );
}

sub get {
    # На вход получаем кол-во запрашиваемых сообщений
    my $limit = shift;
    # Открытие файла, чтение N записей
    # Надо предусмотреть, что файла может не быть, а так же в файле может быть меньше сообщений чем запрошено
    my $ret = []; # Возвращаем ссылку на массив строк
    
    open(my $fh, "<", $file_path) or die "Can't open < $file_path: $!";
    for (my $i = 0; ($i < $limit) && !eof($fh); $i++) { 
    	my $ex = <$fh>;
    	push @$ret, chomp($ex); 
    }
	open(my $newFh, ">", "$file_path.temp") or die "Can't open > $file_path.temp: $!";
	while (!eof($fh)) { 
		my $str = <$fh>;
		print $newFh $str; 
	}
	close($newFh);
    close($fh);
    
    unlink($file_path);
    rename("$file_path.temp", $file_path) or die "Не удалось переименовать $file_path.temp";
    
    #die "В файле меньше сообщений чем запрошено" unless $i == $limit;

    return $ret;
}

1;
