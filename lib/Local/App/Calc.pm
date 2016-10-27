package Local::App::Calc;

use strict;
use IO::Socket;
use FindBin;
require "$FindBin::Bin/../lib/Local/Calculator/evaluate.pl";
require "$FindBin::Bin/../lib/Local/Calculator/rpn.pl";

#Определение обрабатываемых сигналов
#$SIG{ALRM} = sub {die "Timeout"};

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
		$client->autoflush(1);
		my $msg;
		while (sysread($client, $msg, 4) == 4) {
			my $len = unpack 'L', $msg;
			die "Не могу прочесть сообщение" unless sysread($client, $msg, $len) == $len;
			syswrite($client, pack('L/a*', calculate($msg)));
		}
		close( $client );
	}
	close( $server );
}

sub calculate {
    my $ex = shift;
    
    # На вход получаем пример, который надо обработать, на выход возвращаем результат
    my $res;
    eval {
		my $rpn = rpn($ex);
		$res = evaluate($rpn);
	1} or do {
		$res = "Error: $@";
	};
	return $res;
}

1;
