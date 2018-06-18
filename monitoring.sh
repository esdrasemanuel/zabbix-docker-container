#!/bin/bash

# pendencia, instalar o bc
consumo_memoria(){
	docker stats --no-stream > stats_docker.txt
	NUMBER_LINE=`cat stats_docker.txt | wc -l`
	cat stats_docker.txt | tail -n `expr $NUMBER_LINE - 1` |tr -s " " > consumo_aux.txt

	LINE=`expr $NUMBER_LINE - 1`
	total_aux=0

	TAIL=1
	for HEAD in `seq $LINE`
	do
		valor=`cat consumo_aux.txt | head -n $HEAD | tail -n $TAIL | cut -d" " -f6 | cut -d"%" -f1`
		total_aux=$(echo "scale=2; $total_aux + $valor" | bc)
	done

	total=`echo "scale=2; $total_aux / $LINE" | bc`
	rm -rf consumo_aux.txt
	if [ ${total} \< 0 ]
	then
		echo "0${total}" > consumo_total.txt
	else
		echo ${total} > consumo_total.txt
	fi
}
while [ 1 \> 0 ]
do
	sleep 10
	consumo_memoria
done
