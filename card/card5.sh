#!/usr/bin/env bash
IP=$2
HEAD="\x6c\x69\x6e\x75\x78\x69\x6d\x2e\x72\x75\x0a"
battlestaf=(127150 127137) #Временно наполнен
black_card='\U1F0A0'
declare -a onestaf
declare -a twostaf
declare -a battlestaf
declare -a trashstaf
declare -a shuf_card
switch(){
	#flag=$(((flag+1)%2))
	if [[ $flag == 0 ]]; then
		STATUSSTR="Ход партнера"
		flag=1
	else
		STATUSSTR="Ваш ход"
		flag=0
fi
}
razdacha(){
	local p=0
	local s=0
	for ((i=35; i>23; i--)); do
		if [[ $[ $i%2 ] == 0 ]]; then
			onestaf[p]=${shuf_card[i]}
			((p+=1))
			unset shuf_card[i]
		else
			twostaf[s]=${shuf_card[i]}
			((s+=1))
			unset shuf_card[i]
		fi
	done
unset i
}
printColor(){
	for tin in $@; do
		if [[ $tin -gt 127150 && $tin -lt 127185 ]]; then
			tput setaf 1
			printf '%b ' "\U$(bc<<<"obase=16;$tin")"
			tput sgr0
		else
			printf '%b ' "\U$(bc<<<"obase=16;$tin")"
		fi
	done
}
printHead(){
	trashstaf=(1 5)
	tput cup 1 15
	tput el
	printf '%s' "$STATUSSTR"
	tput cup 2 1
	tput el
	printColor ${shuf_card[@]:0:1}
	if [[ ${#shuf_card[@]} -gt 1 ]]; then
		tput setaf 4
		printf '%b' "$black_card"
		tput sgr0
	fi
	tput cup 6 48
	tput el
	if [[ ${#trashstaf} -gt 0 ]]; then
		tput setaf 4
		printf '%b' "$black_card"
		tput sgr0
	fi
	tput cup 10 15
	tput el
	if [[ ${#battlestaf[@]} -gt 0 ]]; then
		printColor ${battlestaf[@]}
	fi
	tput cup 14 1
	tput el
	printColor ${onestaf[@]}
	tput cup 16 30
	tput el
	for ((i=0; i<${#twostaf[@]}; i++)); do
		tput setaf 4
		printf '%b ' "$black_card"
	done
	tput sgr0
}

#Ставим переключатель и делаем рабочим следующий код для первого игрока с меткой flag=0 или 1 параметром
#count=0

if [[ $IP ]]; then
	coproc nc -w 5 $1 $2
	flag=$((RANDOM%2))
	echo "$flag" >&${COPROC[1]}
	read -u ${COPROC[0]} flagek
else
	coproc nc -l -p $1
	read -u ${COPROC[0]} flagek
	flag=$(((flagek+1)%2))
	echo "$flag" >&${COPROC[1]}
fi
[[ $flagek && $((flag+flagek)) == 1 ]] || exit
if [[ $flag == 0 ]]; then
	STATUSSTR="Ваш ход"
	number_min=$(bc<<<"ibase=16;1F0A1")
	number_min1=$(bc<<<"ibase=16;1F0A6")
	number_min2=$(bc<<<"ibase=16;1F0AD")
	#number_min=$(printf '%d' '0X1F0A7')
	#number_min="$(printf '%b' '\U1F0A1')"
	number_max1=$(bc<<<"ibase=16;1F0AB")
	number_max2=$(bc<<<"ibase=16;1F0AE")
	##Запишим набор одной масти в асоциативный массив
	z=1
	declare -A monst
	while read monst["num$z"]; do
		#monst[num$z]
		#echo ${monst["num$z"]}
		((z+=1))
	done <<<"$number_min
	$(seq $number_min1 $number_max1)
	$(seq $number_min2 $number_max2)" 
	unset monst["num$z"]
	
	##Создадим полный набор одной колоды и запишем в массив
	declare -a arrvar
	a=0
	for ((i=0; i<4; i++)); do
		for y in ${!monst[@]}; do
			arrvar[$a]=${monst[$y]}
			((a+=1))
			((monst[$y]+=16))
		done
	done
	
	##Перемешаем колоду
	s=0
	for p in $(shuf -i 0-35); do
		shuf_card[p]=${arrvar[@]:s:1}
		((s+=1))
	done
	
	##раздаем карты в 2 поля(массива) но предусмотренно еще два "бой" и "полебоя"
	razdacha
	echo ${onestaf[@]} >&${COPROC[1]}
	echo ${twostaf[@]} >&${COPROC[1]}
	echo ${shuf_card[@]} >&${COPROC[1]}
else
	STATUSSTR="Ход партнера"
	read -u ${COPROC[0]} -a twostaf
	read -u ${COPROC[0]} -a onestaf
	read -u ${COPROC[0]} -a shuf_card
fi

tput civis
stty -icanon
tput clear
printHead
while true; do  #главный цикл в котором все и происходит игровой процесс "движок"
	if [[ $flag == 1 ]]; then
			echo -en "\e[?9l"
			read -u ${COPROC[0]} -a twostaf
			read -u ${COPROC[0]} -a battlestaf
	else
		echo -en "\e[?9h"
		read -rsn 6 x
		string="$(hexdump -C <<<$x)" #конвертируем кракозябки в данные из цифр
		CLICK=${string:19:2}
		MOUSE=${string:22:2}${string:25:3}
		X=$((16#${string:22:2}))
		Y=$((16#${string:25:3}))
		if [[ $(($X%2)) == 0 ]]; then #карта состоит из двух столбцов объединим это 
			ZNAK=$((($X-33)/2))
		else
			ZNAK=$((($X-34)/2))
		fi
		#echo -e "$CLICK\n$MOUSE" >>mouse.txt #здесь мы записывали координаты на стадии отладки
		#Сравниваем battlestaf < 11 или не нажата ли правая клавиша на батлстаф - переход хода
		# или забрал если игрок под номером 2 и отправка к блоку набора карт
		#правой кнопкой мыши на любую из карт на поле боя
		[[ $CLICK == 21 ]] && break #выход из игры
		[[ $CLICK == 20 && $Y == 47 ]] || continue
		[[ ${onestaf[ZNAK]} ]] || continue
		battlestaf+=(${onestaf[ZNAK]})
		unset onestaf[ZNAK]
		onestaf_tmp=(${onestaf[@]})
		onestaf=(${onestaf_tmp[@]})
		unset onestaf_tmp
		echo ${onestaf[@]} >&${COPROC[1]}
		echo ${battlestaf[@]} >&${COPROC[1]}
	fi
	switch
	printHead
done
echo -en "\e[?9l" #надо в дальнейшем выключить только для оставшегося
stty icanon
tput cvvis
tput clear
echo -e $HEAD 
#tput cnorm
