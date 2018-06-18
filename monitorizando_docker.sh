#!/bin/bash

IP=0
MAX_VALUE=0
LAST_VALUE=0
USUARIO=""
SENHA=""
PAGE=""
ID=0
URL='http://10.0.0.5/zabbix/api_jsonrpc.php'
HEADER="Content-Type:application/json"
TOKEN=0

pegando_token(){

	JSON='
	{
		"jsonrpc": "2.0",
		"method": "user.login",
		"params": {
			"user": "Admin",
			"password": "zabbix"
		},
		"id": 0
	}'
	curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | cut -d '"' -f8
}


pegando_hosts(){
	JSON='
	{
    		"jsonrpc": "2.0",
    		"method": "host.get",
    		"params": {
        		"output": [
            			"hostid",
            			"host"
        		],
        		"monitored_hosts": 1
    		},
    		"id": 1,
    		"auth": "'$TOKEN'"
	}'
	echo " ID   - HOSTNAME"
	curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | awk -v RS='{"' -F\" '/^hostid/ {printf $3 " - " $7 "\n"}'
}


#pegando_hosts

pegando_ID(){
	read -p "Escolha o ID do Host: " ID
}

pegando_valor(){
	JSON='
	{
		"jsonrpc": "2.0",
		"method": "item.get",
    		"params": {
       			"output": "extend",
        		"hostids": "'$ID'",
        		"search": {
            			"key_": "ssh"
        		},
        		"sortfield": "name"
    		},
    		"auth": "'$TOKEN'",
    		"id": 1
	}'
	curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | python -mjson.tool | grep "lastvalue" | cut -d"\"" -f4
}

pegando_usuario(){
        JSON='
        {
                "jsonrpc": "2.0",
                "method": "item.get",
                "params": {
                        "output": "extend",
                        "hostids": "'$ID'",
                        "search": {
                                "key_": "ssh"
                        },
                        "sortfield": "name"
                },
                "auth": "'$TOKEN'",
                "id": 1
        }'
        USUARIO=`curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | python -mjson.tool | grep "username" | cut -d"\"" -f4`
        SENHA=`curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | python -mjson.tool | grep "password" | cut -d"\"" -f4`
	IP=`curl -s -X POST -H "$HEADER" -d "$JSON" "$URL" | python -mjson.tool | grep "key_" | cut -d"]" -f1 | cut -d"," -f2`
}


defini_valor(){
	read -p "Digite o valor para ativar o gatilho: " MAX_VALUE
}


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

command_view(){
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
	PAGE="relatorio_auto.html"
	tag_h1 "Relatorio"
	memoria ${ID_CONTAINER}
	lista_conteudo ${ID_CONTAINER}
	lista_processos ${ID_CONTAINER}
	lista_carga ${ID_CONTAINER}
	wkhtmltopdf http://localhost/${PAGE} /home/gerencia/relatorio_auto.pdf
	rm -rf /var/www/html/${PAGE}

}


fazer_relatorio(){
	printf "1 - Relatorio automatico\n2 - Relatorio manual\n"
	read -p "Digire sua escolha: " OP
	if [ ${OP} -eq 1 ]
	then
		sshpass -p${SENHA} ssh ${USUARIO}@${IP} "docker stats --no-stream"
		read -p "Digite o ID do container: " CONTAINER
		relatorio_auto ${CONTAINER}
	elif [ ${OP} -eq 2 ]
	then
		PAGE="relatorio_manual.html"
		sshpass -p${SENHA} ssh ${USUARIO}@${IP} "docker stats --no-stream"
                read -p "Digite o ID do container: " CONTAINER
		CONT=1
		read -p "Titulo (curto) do Relatorio: " TITLE
		tag_h1 "${TITLE}"
		echo "Crie Secoes de acordo com os comandos que você for usar"
		echo "ESPERE 7 segundos"
		sleep 7
		clear
		while [ ${CONT} \> 0 ]
		do
			echo "LEMBRETE: Caso deseje parar o relatorio, deixe um dos campos abaixo vazio"
			read -p "Relatorio de (e.x: informacoes da memoria): " REL
			tag_h3 "${REL}"
			read -p "Comando: " aux_comando
			clear
			if [ -z "${REL}" -o -z "${aux_comando}" ]
                        then
				CONT=0
			else
				echo "SAIDA"
				command_view "docker exec ${CONTAINER} ${aux_comando}"
				tag_pre_o
				command "docker exec ${CONTAINER} ${aux_comando}"
				tag_pre_c
			fi
		done
		wkhtmltopdf http://localhost/${PAGE} /home/gerencia/relatorio_manual.pdf
        	rm -rf /var/www/html/${PAGE}
	fi
}

parando_containers(){
	sshpass -p${SENHA} ssh ${USUARIO}@${IP} "docker stats --no-stream"
        read -p "Digite o ID(s) do(s) container(s): " CONTAINER
	for id_container in `echo ${CONTAINER}`;
	do
		sshpass -p${SENHA} ssh ${USUARIO}@${IP} "docker stop ${id_container}" >> /dev/null
		echo "Parando Container ${id_container}"
	done
}

armazenando_dados(){
	while [ 1 \> 0 ]
	do
		sleep 45
		data=`date`

		dia=`echo ${data} | cut -d" " -f3`
		mes=`echo ${data} | cut -d" " -f2`
		ano=`echo ${data} | cut -d" " -f6`
		hora=`echo ${data} | cut -d" " -f4`

		format_data="${dia}/${mes}/${ano} ${hora}"
		valor=`pegando_valor`
		echo "${format_data} - ${valor}" >> dados_consumo.txt
	done
}

para_continuar(){
	read -p "Enter para voltar ao menu..."
        clear
}

manual(){
	OP=0
	while [ ${OP} -ne 4 ]
	do
		printf "1 - Ultimo valor coletado\n2 - Fazer Relatorio\n3 - Parar Container(s)\n4 - Sair\n"
		read -p "Opção: " OP
		if [ ${OP} -eq 1 ]
		then
			valor=`pegando_valor`
			printf "Ultimo valor: ${valor}\n\n"
			para_continuar
		elif [ ${OP} -eq 2 ]
		then
			fazer_relatorio
			para_continuar
		elif [ ${OP} -eq 3 ]
		then
			parando_containers
			para_continuar
		fi
	done
}

incidente(){
	EX=0
	while [ ${EX} \< 1 ]
	do
        	VALOR=`pegando_valor`
        	while [ ${VALOR} \< ${MAX_VALUE} ]
        	do
			sleep 28
			echo "Coletando dados..."
			sleep 2
			VALOR=`pegando_valor`
			clear
        	done
		manual
		exit 1
	done
}

tipo_monitoramento(){
	echo "Que tipo de monitorização deseja:"
	printf "     1 - Manual\n     2 - Esperar Incidente\n"
	read -p "Opçao: " OP
	if [ ${OP} -eq 1 ]
	then
		manual
	elif [ ${OP} -eq 2 ]
	then
		incidente
	fi
}


main(){
	TOKEN=`pegando_token`
	pegando_hosts
	pegando_ID
#	armazenando_dados &
	pegando_usuario
	defini_valor
	tipo_monitoramento
}

main
