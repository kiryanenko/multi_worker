package Local::App::Calc;

use strict;
use IO::Socket;
use Local::App::ProcessCalc;

#Определение обрабатываемых сигналов
$SIG{__ALRM__} = sub {
    new_one();
};

sub start_server {
    # На вход получаем порт который будет слушать сервер занимающийся расчетами примеров
    my $port = shift;
    
    # Создание сервера и обработка входящих соединений, форки не нужны 
    # Входящее и исходящее сообщение: int 4 byte + string
    # На каждое подключение отдельный процесс. В рамках одного соединения может быть передано несколько примеров
    
	my $server = IO::Socket::INET->new(
		LocalPort => $port,
		Type      => SOCK_STREAM,
		ReuseAddr => 1,
		Listen    => 10) 
	or die "Can't create server on port $port : $@ $/";

	while(my $client = $server->accept()){
		my $msg_len;
		if (sysread($client, $msg_len, 4) == 4){
		    my $len = unpack 'L', $msg_len;
			if (sysread($client, $msg_ex, $len) == $len) {
				my $ex = unpack('a*', $msg_ex);
				Local::App::ProcessCalc::multi_calc(10, $ex, $port)
			} else die "Не могу прочесть сообщение";
		} else die "Не могу прочесть сообщение";
		close( $client );
	}
	close( $server );
}

sub calculate {
    my $ex = shift;
    # На вход получаем пример, который надо обработать, на выход возвращаем результат
}

1;
