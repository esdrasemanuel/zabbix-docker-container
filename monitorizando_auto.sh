#!/bin/bash

IP=''
USUARIO=''
SENHA=''
RELATORIO=0
PARAR=0
USO_MAXIMO=20
HASH=`date | md5sum | cut -d" " -f1`
PAGE="${HASH}.html"
DIR=""

tag_h1(){
	echo "<h1> $1 </h1>" >> /var/www/html/${PAGE}
}

tag_h3(){
	echo "<h3> $1 </h3>" >> /var/www/html/${PAGE}
}

tag_h4(){
        echo "<h4> $1 </h4>" >> /var/www/html/$PAGE
}

tag_pre_o(){
	echo "<pre>" >> /var/www/html/${PAGE}
}

tag_pre_c(){
        echo "</pre>" >> /var/www/html/${PAGE}
}

command(){
	sshpass -p${SENHA} ssh ${USUARIO}@${IP} $1 >> /var/www/html/${PAGE}
}

command_final(){
	sshpass -p${SENHA} ssh ${USUARIO}@${IP} $1
}

memoria(){
	tag_h3 "Informacoes da Memoria"
	tag_pre_o
	command "docker exec $1 cat /proc/meminfo"
	tag_pre_c
}

lista_conteudo(){
	tag_h3 "Listando Conteudo dos diretorios /, /home e /root"
	tag_h4 "Diretorio / (raiz)"

	tag_pre_o
	command "docker exec $1 ls -a /"
	tag_pre_c

	tag_h4 "Diretorio /root"
	tag_pre_o
	command "docker exec $1 ls -a /root"
	tag_pre_c

	tag_h4 "Diretorio /home"
	tag_pre_o
	command "docker exec $1 ls -a /home"
	tag_pre_c
}

lista_processos(){
	tag_h3 "Listando Processos"
	tag_pre_o
	command "docker exec $1 ps aux"
	tag_pre_c
}

lista_carga(){
	tag_h3 "Carga Media do Sistema"
        tag_pre_o
        command "docker exec $1 cat /proc/loadavg"
        tag_pre_c
}

relatorio_auto(){
	#RECEBE UM ID
	#Funçao faz relatorio sobre informações da memoria, lista o conteudo em angus diretorios, lista os processos e carga media
	ID_CONTAINER=${1}
	tag_h1 "Relatorio $ID_CONTAINER"
	memoria ${ID_CONTAINER}
	lista_conteudo ${ID_CONTAINER}
	lista_processos ${ID_CONTAINER}
	lista_carga ${ID_CONTAINER}
	wkhtmltopdf http://localhost/${PAGE} $DIR/relatorios/$HASH.pdf
	echo "Relatorio ${HASH}.pdf Disponivel em $DIR"
	rm -rf /var/www/html/${PAGE}

}

ajuda(){
	printf "Usage: $0 [-OPTIONS] [ARGUMENTS]\n\n\
OPTIONS:\n\
	-r ---> To activate or not the reports, value 1 is active and value 0 is deactivated.\n\
	-p ---> For stop containers automatically, value 1 is active and value 0 is deactivated.\n\
	-m ---> To set the maximum usage in percent (integer) of the memory of each container. Containers using memory above this value will be stopped.\n\
	-i ---> Target IP.\n\
	-u ---> Target machine user.\n\
	-s ---> User password in target maquia.\n\
	-d ---> Path of full scripts directory (path only) on zabbix server.\n\

EXEMPLES:\n\
	$0 -r 1 -p 1 -m 30 -i 10.0.0.2 -u userdocker -s passdocker -d /home/docker\n\
	>> Containers using memory above 30 percent will be reported and then stopped.<< \n"
	exit 1
}


if [ $# \> 1 ]
then
	while getopts "r:p:m:i:u:s:d:h" OPTVAR
	do
		if [ $OPTVAR == "r" ]
		then
			RELATORIO=$OPTARG
		elif [ $OPTVAR == "p" ]
		then
			PARAR=$OPTARG
		elif [ $OPTVAR == "m" ]
		then
			USO_MAXIMO=$OPTARG
		elif [ $OPTVAR == "i" ]
		then
			IP=$OPTARG
		elif [ $OPTVAR == "u" ]
		then
			USUARIO=$OPTARG
		elif [ $OPTVAR == "s" ]
		then
			SENHA=$OPTARG
		elif [ $OPTVAR == "d" ]
		then
			DIR=$OPTARG
		fi
	done
elif [ $# -eq 1 ]
then
	if [ $1 == "-h" ]
	then
		ajuda
	fi
fi

command_final "docker stats --no-stream" > $DIR/estado_atual.txt

LINHA=`cat $DIR/estado_atual.txt | wc -l`
LINHA_C=`expr $LINHA - 1`
cat $DIR/estado_atual.txt | tail -n $LINHA_C > $DIR/dados.txt

TAIL=1

for HEAD in `seq $LINHA_C`
do
	CONTEUDO=`cat $DIR/dados.txt | head -n $HEAD | tail -n $TAIL | tr -s " "`
	PERCENTE=`echo $CONTEUDO | cut -d" " -f6 | cut -d"%" -f1`
	ID=`echo $CONTEUDO | cut -d" " -f1`
	if [ $PERCENTE \> $USO_MAXIMO ]
	then
		if [ $RELATORIO -eq 1 ]
		then
			HASH=`date | md5sum | cut -d" " -f1`
			PAGE="${HASH}.html"
			relatorio_auto $ID
		fi
		if [ $PARAR -eq 1 ]
		then
			command_final "docker stop $ID" > /dev/null
			echo "Status do container $ID = PARADO"
		fi
	fi
done
