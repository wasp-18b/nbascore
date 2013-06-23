# .chanset $chan +nbascore

namespace eval nbascore {

	# настройки
	# сколько последних действий показываются при запуске Play-By-Play активной игры
	set lastactionsnum 10

	# интервалы опроса
	set idleinterval 120
	set activeinterval 10

	set idleinterval [expr $idleinterval * 1000]
	set activeinterval [expr $activeinterval * 1000]

	variable teams
	array set teams {
		BOS "\00303Boston Celtics"
		BKN "Brooklyn Nets"
		NY "\00312New York Knicks"
		PHI "\00304Philadlphia 76ers"
		TOR "\00304Toronto Raptors"
		CHI "\00304Chicago Bulls"
		CLE "\00304Cleveland Cavaliers"
		DET "\00302Detroit Pistons"
		IND "Indiana Pacers"
		MIL "\00303Milwaukee Bucks"
		ATL "\00304Atlanta Hawks"
		CHA "\00307Charlotte Bobcats"
		MIA "\00304Miami Heat"
		ORL "\00312Orlando Magic"
		WSH "\00302Washington Wizards"
		GS "\00302Golden State Warriors"
		LAC "\00304Los Angeles Clippers"
		LAL "\00302Los Angeles Lakers"
		PHX "\00302Phoenix Suns"
		SAC "\00302Sacramento Kings"
		DAL "\00312Dallas Mavericks"
		HOU "\00304Houston Rockets"
		MEM "\00302Memphis Grizzlies"
		NO "\00312New Orleans Hornets"
		SA "San Antonio Spurs"
		DEN "\00312Denver Nuggets"
		MIN "Minnesota Timberwolves"
		OKC "\00312Oklahoma City Thunder"
		POR "\00304Portland Trail Blazers"
		UTAH "\00302Utah Jazz"
	}

	# Переменная с сегодняшней датой
	variable todaydate

	# разница во времени
	variable timeoffset
	set timeoffset 8


	# Списки с играми и их gameId
	variable gameslist
	variable gamesidlist
	
	# Списки играми для наблюдения
	variable watchlist
	if {![info exists watchlist]} {set watchlist [list]}

	variable playbyplay
	if {![info exists playbyplay]} {set playbyplay [list]}

	# Переменные для Playbyplay
	# Период опроса (сек)
	variable period
	set period 15

	# ID игры
	variable gameid
	# список с данными последнего сообщения на канале
	variable lastaction
	# канал
	variable nbalivechan
	# состояние
	variable playbyplayactive
	if {![info exists playbyplayactive]} {set playbyplayactive 0}
	# команда-стоп
	variable playbyplaystop
	set playbyplaystop 0
	# id таймера playbyplay
	variable playbyplayid

	setudef flag nbascore
	setudef flag nbalive

	package require http 2.7
	package require mysqltcl 3.0

	bind pub - "!help" ::nbascore::help
	bind pub - "!*" ::nbascore::allgames
	bind pub - "!+" ::nbascore::activegames
	bind pub - "!<" ::nbascore::yesterdaygames
	bind pub - "!Б" ::nbascore::yesterdaygames
	bind pub - "!<<" ::nbascore::daybeforeyesterdaygames
	bind pub - "!ББ" ::nbascore::daybeforeyesterdaygames
	bind pub - "!>" ::nbascore::tomorrowgames
	bind pub - "!Ю" ::nbascore::tomorrowgames
	bind pub - "!>>" ::nbascore::dayaftertomorrowgames
	bind pub - "!ЮЮ" ::nbascore::dayaftertomorrowgames
	# bind pub - "!?" ::nbascore::listofgames
	bind pub - "!?" ::nbascore::detailstats
	bind pub - "!#" ::nbascore::addtimer
	bind pub - "!timers" ::nbascore::timers
	bind pub - "!remove" ::nbascore::removetimer
	bind pub - "!watch" ::nbascore::watch
	bind pub - "!stop" ::nbascore::stop
	bind pub - "!fouls" ::nbascore::fouls
	bind pub - "!points" ::nbascore::points
	bind pub - "!stand" ::nbascore::stand
	bind pub - "!if" ::nbascore::iftoday
	bind join - "*" ::nbascore::onjoin

	# тестовые бинды
	bind msg o "!test-box" ::nbascore::test-box
	bind msg o "!test-pbp" ::nbascore::test-pbp
	bind msg o "!long2short" ::nbascore::test-lts
	bind msg o "!test" ::nbascore::test
	bind msg o "!test-bd" ::nbascore::test-bd

	# !? 15-05-12
	# !? 15-05-12 <номер игры>
	# !? 15-05-12 <номер игры> <игроки через пробел>

	# !* 
	# !* <номер игры>
	# !* <номер игры> <игроки через пробел>

	proc ::nbascore::test-bd {nick host hand text} \
	{
		set db [::mysql::connect -host localhost -user nba -password nbaorbb -db nba]

		set result [::mysql::sel $db {SELECT division FROM division}]

		::mysql::map $db {division} {
			# putserv "PRIVMSG $nick $division"
		}

		putlog "[::mysql::info $db sqlstate]"

		set arena "Barclays Center, Brooklyn, NY"

		# set result [::mysql::query $db "INSERT INTO teams(team, city, name, short, teamid, division, arena) VALUES ('Brooklyn Nets', 'Brooklyn', 'Nets', 'BKN', 'bkn', 1, '$arena')"]
		# putlog "[::mysql::insertid $db]"
		# putlog "[::mysql::info $db info]"
		putlog "[::mysql::info $db sqlstate]"

		# for {set i 0} {$i < [llength $result]} {incr i} {
		# 	set row [lindex $result $i]
		# 	putserv "PRIVMSG $nick :$row"
		# }


		# set query [::mysql::query $db {SELECT division FROM division}]
		::mysql::close $db
	}

	# Ответ на !help
	proc ::nbascore::help {nick host hand chan text} {
		
		if {![channel get $chan nbascore]} {return}

		putserv "NOTICE $nick :!* - все игры сегодняшнего дня"
		putserv "NOTICE $nick :!+ - все текущие игры"
		putserv "NOTICE $nick :!< - вчерашние игры"
		putserv "NOTICE $nick :!<< - позавчерашние игры"
		putserv "NOTICE $nick :!> - игры завтрашнего дня"
		putserv "NOTICE $nick :!>> - игры послезавтрашнего дня"	
		putserv "NOTICE $nick :!? - список игр"
		putserv "NOTICE $nick :!? <номер игры> - детальная информация об игре"
		putserv "NOTICE $nick :!? <номер игры> <игрок> <игрок> - детальная статистика игрока/игроков в игре"
		putserv "NOTICE $nick :!stand - положение команд в конференциях"
		putserv "NOTICE $nick :!if - пары плейофф, если бы сезон завершился прямо сейчас"
	}

	# Приветственный нотис входящему
	proc ::nbascore::onjoin {nick host hand chan} {

		if {![channel get $chan nbascore]} {return}

		putserv "NOTICE $nick :чтобы узнать доступные команды, отправь в канал !help"
	}

	# Все игры дня
	proc ::nbascore::allgames {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}

		set scoreboard [::nbascore::Scoreboard]

		set ::nbascore::gamesidlist [list]
		set ::nbascore::gameslist [list]

		set datelist [lindex $scoreboard 0]
		set date "[lindex $datelist 0] [lindex $datelist 1] [lindex $datelist 2]"

		set numgames [llength $scoreboard]
		putserv "PRIVMSG $chan :$date ([expr $numgames - 1] games)"
		set i 1

		while {$i < $numgames} {
			set gamescore [lindex $scoreboard $i]
			set gameid [lindex $gamescore 0]
			set gamestate [lindex $gamescore 1]
			set ateamshort [lindex $gamescore 2]
			set ateamlong [lindex $gamescore 3]
			set ascore [lindex $gamescore 5]
			set hteamshort [lindex $gamescore 6]
			set hteamlong [lindex $gamescore 7]
			set hscore [lindex $gamescore 9]

			if {[string match {*ET} $gamestate]} {
				regsub {\s*ET} $gamestate "" gametime
				set gamestate "\00304[::nbascore::TimeRemain "$gametime $date"]\017/$gametime"
				set divider "\017@"
			} else {
				if {$ascore > $hscore} {set divider ">"}
				if {$ascore < $hscore} {set divider "<"}
				if {$ascore == $hscore} {set divider "="}
				# set divider "\00310,10$ascore $divider $hscore\017"
				set divider "\00310,10$ascore $divider $hscore\017"
			}
			if {[string match "*Qtr" $gamestate]} {set status [string range $gamestate 0 [expr [string last Qtr $gamestate] - 2]]}
			regsub {Final} $gamestate "F" gamestate
			regsub {\s*Qtr} $gamestate "" gamestate

			putserv "PRIVMSG $chan :$i. \[$gamestate\] \002$::nbascore::teams($ateamshort)\002 $divider \002$::nbascore::teams($hteamshort)\002"

			lappend ::nbascore::gamesidlist $gameid
			lappend ::nbascore::gameslist "$ateamshort@$hteamshort"

			incr i
		}
	}

	# Только текущие игры
	proc ::nbascore::activegames {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}

		set scoreboard [::nbascore::Scoreboard]

		set numgames [llength $scoreboard]
		set i 1

		while {$i < $numgames} {
			set gamescore [lindex $scoreboard $i]
			set gamestate [lindex $gamescore 1]
			set ateamshort [lindex $gamescore 2]
			set ateamlong [lindex $gamescore 3]
			set ascore [lindex $gamescore 5]
			set hteamshort [lindex $gamescore 6]
			set hteamlong [lindex $gamescore 7]
			set hscore [lindex $gamescore 9]

			if {![string match {*ET} $gamestate]} {
				if {![string match {*Final*} $gamestate]} {
					if {$ascore > $hscore} {set divider ">"}
					if {$ascore < $hscore} {set divider "<"}
					if {$ascore == $hscore} {set divider "="}
					regsub {\s*Qtr} $gamestate "" gamestate
					# set gamestate [string trim $gamestate]
					# set divider "\037\00310,10$ascore $divider $hscore\037\017"
					set divider "\00310,10$ascore $divider $hscore\017"
					putserv "PRIVMSG $chan :\[$gamestate\] \002$::nbascore::teams($ateamshort)\002 $divider \002$::nbascore::teams($hteamshort)\002"
				}
			}

			incr i
		}
	}

	# Игры вчерашнего дня
	proc ::nbascore::yesterdaygames {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}
		
		set scoreboard [::nbascore::Scoreboard]

		set datelist [lindex $scoreboard 0]
		set longdate [lindex $datelist 3]

		set longdate [::nbascore::Yesterday $longdate]

		set scoreboard [::nbascore::Scoreboard $longdate]

		set datelist [lindex $scoreboard 0]
		set date "[lindex $datelist 0] [lindex $datelist 1] [lindex $datelist 2]"

		set numgames [llength $scoreboard]
		putserv "PRIVMSG $chan :$date ([expr $numgames - 1] games)"
		set i 1

		while {$i < $numgames} {
			set gamescore [lindex $scoreboard $i]
			set gamestate [lindex $gamescore 1]
			set ateamshort [lindex $gamescore 2]
			set ateamlong [lindex $gamescore 3]
			set ascore [lindex $gamescore 5]
			set hteamshort [lindex $gamescore 6]
			set hteamlong [lindex $gamescore 7]
			set hscore [lindex $gamescore 9]

			if {$ascore > $hscore} {set divider ">"}
			if {$ascore < $hscore} {set divider "<"}
			if {$ascore == $hscore} {set divider "="}
			set divider "\00310,10$ascore $divider $hscore\017"

			regsub {Final} $gamestate "F" gamestate

			putserv "PRIVMSG $chan :\[$gamestate\] \002$::nbascore::teams($ateamshort)\002 $divider \002$::nbascore::teams($hteamshort)\002"

			incr i
		}
	}

	# Игры позавчерашнего дня
	proc ::nbascore::daybeforeyesterdaygames {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}
		
		set scoreboard [::nbascore::Scoreboard]

		set datelist [lindex $scoreboard 0]
		set longdate [lindex $datelist 3]

		set longdate [::nbascore::Yesterday $longdate]
		set longdate [::nbascore::Yesterday $longdate]

		set scoreboard [::nbascore::Scoreboard $longdate]

		set datelist [lindex $scoreboard 0]
		set date "[lindex $datelist 0] [lindex $datelist 1] [lindex $datelist 2]"

		set numgames [llength $scoreboard]
		putserv "PRIVMSG $chan :$date ([expr $numgames - 1] games)"
		set i 1

		while {$i < $numgames} {
			set gamescore [lindex $scoreboard $i]
			set gamestate [lindex $gamescore 1]
			set ateamshort [lindex $gamescore 2]
			set ateamlong [lindex $gamescore 3]
			set ascore [lindex $gamescore 5]
			set hteamshort [lindex $gamescore 6]
			set hteamlong [lindex $gamescore 7]
			set hscore [lindex $gamescore 9]

			if {$ascore > $hscore} {set divider ">"}
			if {$ascore < $hscore} {set divider "<"}
			if {$ascore == $hscore} {set divider "="}
			set divider "\00310,10$ascore $divider $hscore\017"

			regsub {Final} $gamestate "F" gamestate

			putserv "PRIVMSG $chan :\[$gamestate\] \002$::nbascore::teams($ateamshort)\002 $divider \002$::nbascore::teams($hteamshort)\002"
			incr i	
		}	
	}

	# Игры завтрашнего дня
	proc ::nbascore::tomorrowgames {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}
		
		set scoreboard [::nbascore::Scoreboard]

		set datelist [lindex $scoreboard 0]
		set longdate [lindex $datelist 3]

		set longdate [::nbascore::Tomorrow $longdate]

		set scoreboard [::nbascore::Scoreboard $longdate]

		set datelist [lindex $scoreboard 0]
		set date "[lindex $datelist 0] [lindex $datelist 1] [lindex $datelist 2]"

		set numgames [llength $scoreboard]
		putserv "PRIVMSG $chan :$date ([expr $numgames - 1] games)"
		set i 1

		while {$i < $numgames} {
			set gamescore [lindex $scoreboard $i]
			set gamestate [lindex $gamescore 1]
			set ateamshort [lindex $gamescore 2]
			set ateamlong [lindex $gamescore 3]
			set ascore [lindex $gamescore 5]
			set hteamshort [lindex $gamescore 6]
			set hteamlong [lindex $gamescore 7]
			set hscore [lindex $gamescore 9]

			regsub {\s*ET} $gamestate "" gametime
			set gamestate "\00304[::nbascore::TimeRemain "$gametime $date"]\017/$gametime"

			set divider "\017@"

			putserv "PRIVMSG $chan :\[$gamestate\] \002$::nbascore::teams($ateamshort)\002 $divider \002$::nbascore::teams($hteamshort)\002"

			incr i	
		}	
	}

	# Игры послезавтрашнего дня
	proc ::nbascore::dayaftertomorrowgames {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}
		
		set scoreboard [::nbascore::Scoreboard]

		set datelist [lindex $scoreboard 0]
		set longdate [lindex $datelist 3]

		set longdate [::nbascore::Tomorrow $longdate]
		set longdate [::nbascore::Tomorrow $longdate]

		set scoreboard [::nbascore::Scoreboard $longdate]

		set datelist [lindex $scoreboard 0]
		set date "[lindex $datelist 0] [lindex $datelist 1] [lindex $datelist 2]"

		set numgames [llength $scoreboard]
		putserv "PRIVMSG $chan :$date ([expr $numgames - 1] games)"
		set i 1

		while {$i < $numgames} {
			set gamescore [lindex $scoreboard $i]
			set gamestate [lindex $gamescore 1]
			set ateamshort [lindex $gamescore 2]
			set ateamlong [lindex $gamescore 3]
			set ascore [lindex $gamescore 5]
			set hteamshort [lindex $gamescore 6]
			set hteamlong [lindex $gamescore 7]
			set hscore [lindex $gamescore 9]

			set divider "\017@"

			putserv "PRIVMSG $chan :\[$gamestate\] \002$::nbascore::teams($ateamshort)\002 $divider \002$::nbascore::teams($hteamshort)\002"

			incr i	
		}
	}

	# Детальная статистика или список сегодняшних игр (в короткой форме)
	proc ::nbascore::detailstats {nick host hand chan text} {
		
		if {![channel get $chan nbascore]} {return}

		set params [string trim $text]
		set params [split $params]

		# параметров нет - список сегодяшних игр
		if {[llength $params] == 0} {
			set i 0
			set msg ""
			set max [llength $::nbascore::gameslist]
			while {$i < $max} {
				append msg "[expr $i + 1]. [lindex $::nbascore::gameslist $i];  "  
				incr i
			}
			set msg [string trim $msg "; "]
			putserv "PRIVMSG $chan :$msg"
			return
		}


		# берем номер игры, проверяем пределы, получаем gameId
		set gamenum [lindex $params 0]

		set totalgames [llength $::nbascore::gamesidlist]

		if {$gamenum > $totalgames} {return}
		if {$gamenum < 1} {return}

		set gamenum [expr $gamenum - 1]
		set gameid [lindex $::nbascore::gamesidlist $gamenum]

		set boxscorelist [::nbascore::Boxscore $gameid]

		if {$boxscorelist == 0} {return}

		set gamestate [lindex $boxscorelist 3]
		set ateamlist [lindex $boxscorelist 4]
		set hteamlist [lindex $boxscorelist 5]

		set ateam [lindex $ateamlist 2]
		set hteam [lindex $hteamlist 2]

		# если только номер игры - детальная стата об игре
		if {[llength $params] == 1} {

			set ascorelist [lindex $boxscorelist 6]
			set aperflist [lindex $boxscorelist 7]
			set hscorelist [lindex $boxscorelist 8]
			set hperflist [lindex $boxscorelist 9]


			set ascoreline ""
			set hscoreline ""

			set periods [llength $ascorelist]
			set i 0
			while {$i < $periods} {
				set aperiod [lindex $ascorelist $i]
				set hperiod [lindex $hscorelist $i]

				incr i
				if {$i == $periods} {
					set aperiod "\002$aperiod\002"
					set hperiod "\002$hperiod\002"
				}

				if {$aperiod > $hperiod} {
					set ascoreline "$ascoreline \037$aperiod\037"
					set hscoreline "$hscoreline $hperiod"	
				}
				if {$aperiod < $hperiod} {
					set ascoreline "$ascoreline $aperiod"
					set hscoreline "$hscoreline \037$hperiod\037"	
				}
				if {$aperiod == $hperiod} {
					set ascoreline "$ascoreline $aperiod"
					set hscoreline "$hscoreline $hperiod"	
				}
			}
			set ascoreline [string trim $ascoreline]
			set hscoreline [string trim $hscoreline]

			set aperf [join $aperflist "\037: "]
			set hperf [join $hperflist "\037: "]

			set awaydata [lindex $boxscorelist 10]
			set homedata [lindex $boxscorelist 11]
			set awaystat [lindex $awaydata 0]
			set homestat [lindex $homedata 0]
			set awayline [::nbascore::teamStats $awaystat]
			set homeline [::nbascore::teamStats $homestat]

			putserv "PRIVMSG $chan :$ascoreline \002$ateam\002 \037$aperf"
			putserv "PRIVMSG $chan :$hscoreline \002$hteam\002 \037$hperf"
			putserv "PRIVMSG $chan :\002$ateam\002: $awayline"
			putserv "PRIVMSG $chan :\002$hteam\002: $homeline"
			putserv "PRIVMSG $chan :$gamestate"

		} 

		# если есть имена стата по ним
		if {[llength $params] > 1} {
			set i 1
			set players [llength $params]

			while {$i < $players} {
				set player [lindex $params $i]
				set awaydata [lindex $boxscorelist 10]
				set homedata [lindex $boxscorelist 11]
				set max [llength $awaydata]
				set k 1
				while {$k < $max} {
					set playerstat [lindex $awaydata $k]
					set playername [lindex $playerstat 0]
					if {[regexp -nocase -- "$player" $playername match]} {
						set statline [::nbascore::Playerstats $playerstat]
						putserv "PRIVMSG $chan :$ateam@$hteam: \002$ateam\002, $statline"
					}
					incr k
				}
				set max [llength $homedata]
				set k 1
				while {$k < $max} {
					set playerstat [lindex $homedata $k]
					set playername [lindex $playerstat 0]
					if {[regexp -nocase -- "$player" $playername match]} {
						set statline [::nbascore::Playerstats $playerstat]
						putserv "PRIVMSG $chan :$ateam@$hteam: \002$hteam\002, $statline"
					}
					incr k
				}
				incr i
			}
		}
	}


	# добавление таймера. 
	# команда !watch <номер игры> <интервал в сек>
	proc ::nbascore::addtimer {nick host hand chan text} {

		if {![channel get $chan nbascore]} {return}

		# делим $text на части
		set textlist [split $text " "]

		# определяем интервал
		if {[llength $textlist] == 1} {
			set interval 300000
		} else {
			set interval [expr [lindex $textlist 1] * 1000]
		}

		# номер игры
		set gamenum [lindex $textlist 0]
		#set gamenum [expr $gamenum - 1]

		# выгребаем параметры для таймера
		if {$gamenum > [llength $::nbascore::gameslist]} {return}
		if {$gamenum < 1} {return}
		set gamenum [expr $gamenum - 1]
		set gameid [lindex $::nbascore::gamesidlist $gamenum]
		set desc [lindex $::nbascore::gameslist $gamenum]

		#Проверяем наличие игры в списке слежения
		set i 0
		while {$i < [llength $::nbascore::watchlist]} {
			set line [lindex $::nbascore::watchlist $i]
			set watchchan [lindex $line 1]
			set watchgameid [lindex $line 0]
			if {$gameid == $watchgameid && $watchchan == $chan} {
				putserv "PRIVMSG $chan :Эта игра уже есть в списке"
				return
			}
			incr i
		}
			

		# добавляем в список, запускаем таймер
		lappend ::nbascore::watchlist [list $gameid $chan $interval $desc]
		#lappend ::nbascore::watchtimers $timerid
		putserv "PRIVMSG $chan :Added $desc ([expr $interval / 1000] s.)"
		::nbascore::Timer $gameid $chan $interval
	}

	# Положение команд в конференциях
	proc ::nbascore::stand {nick host handle chan text} {

		if {![channel get $chan nbascore]} {return}

		set currentstand [::nbascore::Standings]
		set eastern [lindex $currentstand 0]
		set western [lindex $currentstand 1]

		set eastfirst ""
		set eastlast ""
		set westfirst ""
		set westlast ""

		set i 0
		for {set i 0} {$i < 5} {incr i} {
		 	set west [lindex $western $i]
		 	set team [lindex $west 1]
		 	set won [lindex $west 2]
		 	set loss [lindex $west 3]
		 	set westfirst "$westfirst [expr $i + 1]. \002$team\002 $won-$loss;"
		 	
		 	set east [lindex $eastern $i]
			set team [lindex $east 1]
		 	set won [lindex $east 2]
		 	set loss [lindex $east 3]
		 	set eastfirst "$eastfirst [expr $i + 1]. \002$team\002 $won-$loss;"
		}
		for {set i 5} {$i < 10} {incr i} {
		 	set west [lindex $western $i]
		 	set team [lindex $west 1]
		 	if {$i < 8} {set team "\002$team\002"}
		 	set won [lindex $west 2]
		 	set loss [lindex $west 3]
		 	set westlast "$westlast [expr $i + 1]. $team $won-$loss;"
		 	
		 	set east [lindex $eastern $i]
			set team [lindex $east 1]
			if {$i < 8} {set team "\002$team\002"}
		 	set won [lindex $east 2]
		 	set loss [lindex $east 3]
		 	set eastlast "$eastlast [expr $i + 1]. $team $won-$loss;"
		}

		set eastfirst [string trim $eastfirst " ;"]
		set westfirst [string trim $westfirst " ;"]
		set eastlast [string trim $eastlast " ;"]
		set westlast [string trim $westlast " ;"]

		putserv "PRIVMSG $chan :EAST: $eastfirst"
		putserv "PRIVMSG $chan :EAST: $eastlast"
		putserv "PRIVMSG $chan :WEST: $westfirst"
		putserv "PRIVMSG $chan :WEST: $westlast"
	}

	# Если бы сезон завершился сегодня
	proc ::nbascore::iftoday {nick host handle chan text} {

		if {![channel get $chan nbascore]} {return}

		set currentstand [::nbascore::Standings]
		set eastern [lindex $currentstand 0]
		set western [lindex $currentstand 1]

		set teams [list]
		for {set i 0} {$i < 8} {incr i} {
			lappend teams [lindex [lindex $eastern $i] 1]
		}
		set eastpair1 "\002[lindex $teams 7]\002 vs. \002[lindex $teams 0]\002"
		set eastpair2 "\002[lindex $teams 6]\002 vs. \002[lindex $teams 1]\002"
		set eastpair3 "\002[lindex $teams 5]\002 vs. \002[lindex $teams 2]\002"
		set eastpair4 "\002[lindex $teams 4]\002 vs. \002[lindex $teams 3]\002" 

		set teams [list]
		for {set i 0} {$i < 8} {incr i} {
			lappend teams [lindex [lindex $western $i] 1]
		}
		set westpair1 "\002[lindex $teams 7]\002 vs. \002[lindex $teams 0]\002"
		set westpair2 "\002[lindex $teams 6]\002 vs. \002[lindex $teams 1]\002"
		set westpair3 "\002[lindex $teams 5]\002 vs. \002[lindex $teams 2]\002"
		set westpair4 "\002[lindex $teams 4]\002 vs. \002[lindex $teams 3]\002" 

		putserv "PRIVMSG $chan :EAST: $eastpair1 || $eastpair4"
		putserv "PRIVMSG $chan :EAST: $eastpair2 || $eastpair3"
		putserv "PRIVMSG $chan :WEST: $westpair1 || $westpair4"
		putserv "PRIVMSG $chan :WEST: $westpair2 || $westpair3"
	}

	# Рекурсивный таймер
	proc ::nbascore::Timer {gameid chan interval} {

		# перебираем watchlist в поисках нужного таймера
		foreach line $::nbascore::watchlist {
			if {$gameid == [lindex $line 0]} {
				# нашелся. запрашиваем инфу. 
				if {[::nbascore::Gamestatshort $gameid $chan]} {
					# если игра не окончена, то рекурсируем
					after $interval [list ::nbascore::Timer $gameid $chan $interval]
				} else {
					# если закончена, убиваем из watchlist'a
					set i [lsearch -exact $::nbascore::watchlist $line]
					set ::nbascore::watchlist [lreplace $::nbascore::watchlist $i $i]
				}
			}
		}
	}

	# ??? Выводит текущее состояние игры в короткой форме. Парсер boxscore
	proc ::nbascore::Gamestatshort {gameid chan} {


		::http::config -useragent "Mozilla/5.0 (Windows; U; Windows NT 5.2; rv:1.7.3) Gecko/20040913 Firefox/0.10.1"
		set token [::http::geturl "http://scores.espn.go.com/nba/boxscore?gameId=$gameid"]
		set htmldata [::http::data $token]
		::http::cleanup $token


		if {![regexp -expanded -- {class="game-state">([^<]*)<} $htmldata match gamestate]} {return}
		regsub {In\sProgress\s-\s} $gamestate "" gamestate
		if {[string match {*ET} $gamestate]} {
			return 1
		}

		if {![regexp -expanded -- {<div\sclass="team\saway">.*?<a[^>]*>([^<]*)<.*?<span>([^<]*)</span>} $htmldata match ateam ascore]} {return}
		if {![regexp -expanded -- {<div\sclass="team\shome">.*?<a[^>]*>([^<]*)<.*?<span>([^<]*)</span>} $htmldata match hteam hscore]} {return}
		putserv "PRIVMSG $chan :\[[string trim $gamestate]\] $ateam \002$ascore:$hscore\002 $hteam"

		if {[string match {Final*} $gamestate]} {

			return 0

		} else {

			return 1

		}
	}

	# Выводит список активных таймеров
	proc ::nbascore::timers {nick host handle chan text} {

		if {![channel get $chan nbascore]} {return}

		set activetimers [llength $::nbascore::watchlist]
		putserv "PRIVMSG $chan :In watchlist: $activetimers game(s)"
		if {$activetimers > 0} {
			set i 0
			while {$i < $activetimers} {
				set line [lindex $::nbascore::watchlist $i]
				set gameid [lindex $line 0]
				set watchchan [lindex $line 1]
				set interval [lindex $line 2]
				set interval [expr $interval / 1000]
				set desc [lindex $line 3]
				# set currentnum [lsearch $::nbascore::gamesidlist $gameid]
				# set currentgame [lindex $nbascore::gameslist $currentnum]
				incr i
				putserv "PRIVMSG $chan :$i. $desc ($interval s) on $watchchan"
			}
		}
	}

	# Удаляем таймер
	proc ::nbascore::removetimer {nick host handle chan text} {

		if {![channel get $chan nbascore]} {return}

		# Проверяем, что номер не выходит за число имеющихся таймеров

		if {$text == "all"} {
			set ::nbascore::watchlist [list]
			putserv "PRIVMSG $chan :Watchlist cleared"
			return
		}

		if {$text > [llength $::nbascore::watchlist]} {return}
		if {$text < 1} {return}

		# убиваем из watchlist'a
		# получаем номер в списке
		set i [expr $text - 1]

		# выгребаем описание игры
		set line [lindex $::nbascore::watchlist $i]
		set desc [lindex $line 3]
		set watchchan [lindex $line 1]
		set ::nbascore::watchlist [lreplace $::nbascore::watchlist $i $i]

		putserv "PRIVMSG $chan :Deleted $desc"
		# если таймер удален не на канале слежения, то известим об этом канал слежения
		if {$watchchan != $chan} {
			putserv "PRIVMSG $watchchan :Deleted: $desc"
		}
	}

	# запуск трансляции игры
	proc ::nbascore::watch {nick host handle chan text} {

		if {![channel get $chan nbalive]} {return}

		# если трансляция уже запущена, надо сначала остановить
		if {$::nbascore::playbyplayactive} {
			putserv "PRIVMSG $chan :You need stop active play by play first"
			return
		}

		# проверяем номер, не выходит ли за края числа игр
		if {$text > [llength $::nbascore::gamesidlist]} {return}
		if {$text < 1} {return}

		# получаем gameID 
		set gamenum [expr $text - 1]
		set gameid [lindex $::nbascore::gamesidlist $gamenum]

		::nbascore::PlaybyPlayTranslator $gameid $chan
	}

	# остановка трансляции
	proc ::nbascore::stop {nick host handle chan text} {
		
		if {![channel get $chan nbalive]} {return}

		putlog "stop live"

		if {$::nbascore::playbyplayactive} {
			# set ::nbascore::playbyplaystop 1
			set ::nbascore::playbyplayactive 0
			set ::nbascore::lastaction ""
			putserv "PRIVMSG $chan :Stop of Play by Play"
			after cancel $::nbascore::playbyplayid
			
		}
	}

	# тестовая playbyplay
	proc ::nbascore::test-pbp {nick host handle text} {

		set gameid $text

		set pbplist [::nbascore::Playbyplay $gameid]


		putlog "TEST: titleteams [lindex $pbplist 0]"
		putlog "TEST: titledate [lindex $pbplist 1]"
		putlog "TEST: datatype [lindex $pbplist 2]"
		putlog "TEST: gamestate [lindex $pbplist 3]"
		set ateam [lindex $pbplist 4]
		set hteam [lindex $pbplist 5]
		set ascorelist [lindex $pbplist 6]
		set aperf [lindex $pbplist 7]
		set hscorelist [lindex $pbplist 8]
		set hperf [lindex $pbplist 9]
		set actionlist [lindex $pbplist 10]

		putlog "TEST: ateam [lindex $ateam 0]"
		putlog "TEST: ateam [lindex $ateam 1]"
		putlog "TEST: ateam [lindex $ateam 2]"

		putlog "TEST: hteam [lindex $hteam 0]"
		putlog "TEST: hteam [lindex $hteam 1]"
		putlog "TEST: hteam [lindex $hteam 2]"

		putlog "TEST: ascorelist [join $ascorelist {_}]"
		putlog "TEST: aperf [join $aperf {%}]"
		putlog "TEST: hscorelist [join $hscorelist {_}]"
		putlog "TEST: hperf [join $hperf {%}]"

		putlog "TEST: actionlist has [llength $actionlist] records"
		putlog "TEST: 1st record: [join [lindex $actionlist 0]]"
		putlog "TEST: 10th record: [join [lindex $actionlist 9]]"
	}

	# тестовая boxscore
	proc ::nbascore::test-box {nick host handle text} {

		set gameid $text

		set pbplist [::nbascore::Boxscore $gameid]


		putlog "TEST: titleteams [lindex $pbplist 0]"
		putlog "TEST: titledate [lindex $pbplist 1]"
		putlog "TEST: datatype [lindex $pbplist 2]"
		putlog "TEST: gamestate [lindex $pbplist 3]"
		set ateam [lindex $pbplist 4]
		set hteam [lindex $pbplist 5]
		set ascorelist [lindex $pbplist 6]
		set aperf [lindex $pbplist 7]
		set hscorelist [lindex $pbplist 8]
		set hperf [lindex $pbplist 9]
		set actionlist [lindex $pbplist 10]

		# Закомментирован тест Boxscore
		set awaydata [lindex $pbplist 10]
		set homedata [lindex $pbplist 11]

		putlog "TEST: ateam [lindex $ateam 0]"
		putlog "TEST: ateam [lindex $ateam 1]"
		putlog "TEST: ateam [lindex $ateam 2]"

		putlog "TEST: hteam [lindex $hteam 0]"
		putlog "TEST: hteam [lindex $hteam 1]"
		putlog "TEST: hteam [lindex $hteam 2]"

		putlog "TEST: ascorelist [join $ascorelist {_}]"
		putlog "TEST: aperf [join $aperf {%}]"
		putlog "TEST: hscorelist [join $hscorelist {_}]"
		putlog "TEST: hperf [join $hperf {%}]"

		# Закомментирован тест boxscore
		set awayteamstat [lindex $awaydata 0]
		putlog "TEST: awayteamstat [join $awayteamstat {_}]"
		putlog "TEST: in awaydata [llength $awaydata] records"
		putlog "TEST: awaydata 1 [join [lindex $awaydata 1] {_}]"

		set hometeamstat [lindex $homedata 0]
		putlog "TEST: hometeamstat [join $hometeamstat {_}]"
		putlog "TEST: in homedata [llength $homedata] records"
		putlog "TEST: homedata 1 [join [lindex $homedata 1] {_}]"
	}

	# тестовая фолы
	proc ::nbascore::fouls {nick host handle chan text} {

		set trouble [::nbascore::FoulsTrouble $text]
		putserv "PRIVMSG $chan :[lindex $trouble 0]"
		putserv "PRIVMSG $chan :[lindex $trouble 1]"
	}

	# тестовая очки
	proc ::nbascore::points {nick host handle chan text} {
		set points [::nbascore::PointsLeaders $text]
		putserv "PRIVMSG $chan :[lindex $points 0]"
		putserv "PRIVMSG $chan :[lindex $points 1]"
	}

	proc ::nbascore::test-lts {nick host handle text} {
		set result [::nbascore::LongToShort $text]
		putserv "PRIVMSG $nick :$result"
	}

	proc ::nbascore::test {nick host handle text} {
		::nbascore::Playbyplay-test $text
		putserv "PRIVMSG  $nick finished"
	}


	# ------------------------------------------=== ФУНКЦИИ ===---------------------------------------------------

	# ## ### #### #####
	# Транслятор Play By Play
	# Рекурсивная функция
	# ## ### #### #####
	proc ::nbascore::PlaybyPlayTranslator {gameid chan} {
		
		putlog "PlaybyPlayTranslator"

		# если надо остановить трансляцию
		# if {$::nbascore::playbyplaystop} {
			# set ::nbascore::playbyplaystop 0
			# set ::nbascore::playbyplayactive 0
			# putlog "stop command"
			# return
		# }

		set playbyplaylist [::nbascore::Playbyplay $gameid "full"]
		
		set title [lindex $playbyplaylist 0]
		set date [lindex $playbyplaylist 1]
		set gamestate [lindex $playbyplaylist 3]
		set ateamlist [lindex $playbyplaylist 4]
		set hteamlist [lindex $playbyplaylist 5]
		set ateam [lindex $ateamlist 0]
		set hteam [lindex $hteamlist 0]
		set ateamlast [lindex $ateamlist 1]
		set hteamlast [lindex $hteamlist 1]
		set ateamshort [::nbascore::LongToShort $ateam]
		set hteamshort [::nbascore::LongToShort  $hteam]
		set actionlist [lindex $playbyplaylist 6]

		# дефолтный интервал
		set interval $::nbascore::idleinterval

		# если это первый запуск транслятора
		if {!$::nbascore::playbyplayactive} {

			putlog "first"

			# получаем полный Playbyplay, чтобы сориентироваться
			

			switch -glob -- $gamestate {
				"*Final*" {

					putlog "Final, game already finished"

					if {[llength $actionlist] < $::nbascore::lastactionsnum} {
						set startaction 0
					} else {
						set startaction [expr [llength $actionlist] - $::nbascore::lastactionsnum]
					}

					set lastaction [llength $actionlist]
					
					# ищем в стартовых действиях начало четверти. если находим - передвигаем на него стартовое значение
					set i $startaction
					while {$i < $lastaction} {
						set action [lindex $actionlist $i]
						if {[lindex $action 0] == "quarterstart"} {
							set startaction $i
						}
						incr i
					}
					# на этом этапе имеем откуда и докуда показывать стартовые действия

					# показываем
					set i $startaction
					while {$i < $lastaction} {
						set action [lindex $actionlist $i]
						set actiontext [::nbascore::ActionText $ateamshort $hteamshort $action]
						putserv "PRIVMSG $chan :$actiontext"
						incr i
					}
					
					# выходим без рекурсии
					return

				}
				"*ET" {

					putlog "ET, game not started yet"

					set interval $::nbascore::idleinterval

					regsub {\s*ET} $gamestate "" gametime
					set date [lindex $playbyplaylist 1]
					set timeremain "[::nbascore::TimeRemain "$gametime $date"]"
					if {$timeremain == "now"} {
						putserv "PRIVMSG $chan :Game will start in few minuts"
					} else {
						putserv "PRIVMSG $chan :Game will start in $timeremain remain"
					}

				}
				"" {
					putlog "SOME ERROR"
				}
				default {

					putlog "not ET, play the game"

					# если игра уже идет
					set interval $::nbascore::activeinterval

					# меняем топик 
					putserv "TOPIC $chan :\002[lindex $playbyplaylist 0]\002 ($date)"

					# получаем экшнлист
					set actionlist [lindex $playbyplaylist 6]
					if {[llength $actionlist] != 0} {

						# если там меньше стартового числа записей - стартовое действие нулевое
						if {[llength $actionlist] < $::nbascore::lastactionsnum} {
							set startaction 0
						} else {
							set startaction [expr [llength $actionlist] - $::nbascore::lastactionsnum]
						}

						set lastaction [llength $actionlist]
						
						# ищем в стартовых действиях начало четверти. если находим - передвигаем на него стартовое значение
						set i $startaction
						while {$i < $lastaction} {
							set action [lindex $actionlist $i]
							if {[lindex $action 0] == "quarterstart"} {
								set startaction $i
							}
							incr i
						}
						# на этом этапе имеем откуда и до куда показывать стартовые действия

						set ateamshort [lindex $ateamlist 2]
						set hteamshort [lindex $hteamlist 2]

						# показываем
						set i $startaction
						while {$i < $lastaction} {
							set action [lindex $actionlist $i]
							set actiontext [::nbascore::ActionText $ateamshort $hteamshort $action]
							putserv "PRIVMSG $chan :$actiontext"
							incr i
						}

						# показали
						# записываем последнее действие в ластэкшн
						set ::nbascore::lastaction $action

					}
				}
			}

			set ::nbascore::playbyplayactive 1

		} else {

			# а тут уже основная трансляция
			putlog "iteration"

			# если игра еще не началась
			if {[string match {*ET} $gamestate]} {

				putlog "ET"

				set interval $::nbascore::idleinterval
				
				# putlog "recurse!"
				# putlog "-------------"
				# рекурсируем
				# set ::nbascore::playbyplayid [after $interval [list ::nbascore::PlaybyPlayTranslator $gameid $chan]]

			} else {

				if {$gamestate == ""} {

					putlog "SOME ERROR"
					set interval $::nbascore::activeinterval

				} else {

					putlog "not ET"

					# если игра уже идет
					set interval $::nbascore::activeinterval

					# получаем экшнлист
					set actionlist [lindex $playbyplaylist 6]

					set lastaction [llength $actionlist]

					# ищем начальную запись для отображения на канале
					# если это первые экшены от начала игры	
					if {$::nbascore::lastaction == ""} {

						putlog "first actions in a game"

						# меняем топик 
						# putserv "TOPIC $chan :\002$title\002 ($date)"
						putlog "trying to change TOPIC"
						putserv "TOPIC $chan :\002$title\002 ($date)"
						set startaction 0

					} else {

						putlog "actions not first"

						# если не первые, определяем каким номером в текущем списке
						# идет последнее показанное событие
						# пытаемся найти этот экшн в списке экшнов
						set startaction [lsearch -exact $actionlist $::nbascore::lastaction]
						
						# если не найден, то
						if {$startaction == "-1"} {
							# пока посмотрим, случится ли такое
							# случилось
							set quarter [lindex $::nbascore::lastaction 1]
							set time [clock scan [lindex $::nbascore::lastaction 2]]
							set i 0
							while {$i < $lastaction} {
								set temp [lindex $actionlist $i]
								if {[lindex $temp 1] == $quarter} {
									if {[clock scan [lindex $temp 2]] > $time} {
										set startaction $i
									}
								}
								incr i
							}
						}

						# и начинать будем со следующего
						incr startaction

					}

					# показываем
					if {$startaction < $lastaction} {

						set i $startaction
						while {$i < $lastaction} {
							set action [lindex $actionlist $i]
							set actiontext [::nbascore::ActionText $ateamshort $hteamshort $action]
							putserv "PRIVMSG $chan :$actiontext"
							incr i
						}

						# показали
						# записываем последнее действие в ластэкшн
						set ::nbascore::lastaction $action

						# сюда можно добавить фичечки

						# если таймаут или конец четверти - показываем фолы и очки
						if {[lindex $action 0] == "break"} {
							set fouls [::nbascore::FoulsTrouble $gameid]
							putserv "PRIVMSG $chan :\037Fouls:"
							putserv "PRIVMSG $chan :\002$ateamshort\017: [lindex $fouls 0]"
							putserv "PRIVMSG $chan :\002$hteamshort\017:[lindex $fouls 1]"

							set points [::nbascore::PointsLeaders $gameid]
							putserv "PRIVMSG $chan :\037Points:"
							putserv "PRIVMSG $chan :\002$ateamshort\017: [lindex $points 0]"
							putserv "PRIVMSG $chan :\002$hteamshort\017: [lindex $points 1]"
						}

					}

					if {[string match {*Final*} $gamestate]} {

						putlog "Final detected, stop play by play"
						
						# если игра завершилась
						set ::nbascore::lastaction ""
						set ::nbascore::playbyplayactive 0
						set gamestate [string trim $gamestate]
						putserv "PRIVMSG $chan :\[$gamestate\] \002$ateam\002 $ascore : $hscore \002$hteam\002"
						putserv "TOPIC $chan :\002$ateam\002 $ascore : $hscore \002$hteam\002"
						return

					}
				}

			}
		}
		putlog "recurse!"
		putlog "-------------"
		# рекурсируем
		set ::nbascore::playbyplayid [after $interval [list ::nbascore::PlaybyPlayTranslator $gameid $chan]]
	}

	# ## ### #### #####
	# Возвращает отредактированную строку,
	# готовую для подачи в канал
	# для транслятора Play By Play 
	# ## ### #### #####
	proc ::nbascore::ActionText {ateam hteam action} {

		set typeofaction [lindex $action 0]
		set quarter [lindex $action 1]
		set time [lindex $action 2]
		set score [lindex $action 3]
		set description [lindex $action 4]

		set diff [expr $score]
		if {$diff < 0} {
			set diff [expr -1 * $diff]
			set diff "\00304($diff)\017"
		} else {
			if {$diff > 0} {
				set diff "\00312($diff)\017"
			} else {
				set diff "($diff)"
			}
		}

		# awayscore | awaynoscore | homescore | homenoscore | break | quarterstart
		switch -exact -- $typeofaction {
			"awayscore" {
				return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \002\00312$description $diff"
			}
			"awaynoscore" {
				# return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \00312$description $diff"
				return "\[$quarter\] $time $diff \00312$description"
			}			
			"homescore" {
				return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \002\00304$description $diff"
			}			
			"homenoscore" {
				# return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \00304$description $diff"
				return "\[$quarter\] $time $diff \00304$description"
			}			
			"break" {
				return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \002\00315$description"
			}			
			"quarterstart" {
				return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \037\00315$description"
			}
			default {return "\[$quarter\] $time \00312$ateam\017 $score \00304$hteam \00315$description"}
		}
	}

	# ## ### #### #####
	# Возвращает список со строками с количеством фолов
	# для гостевой и домашней команд
	# ## ### #### #####
	proc ::nbascore::FoulsTrouble {gameid} {

		set boxscorelist [::nbascore::Boxscore $gameid]

		set awaydata [lindex $boxscorelist 10]
		set homedata [lindex $boxscorelist 11]

		set awayplayers [llength $awaydata]
		set homeplayers [llength $homedata]

		set awayplayer [list]
		set awayfouls [list]
		set i 1
		while {$i < $awayplayers} {
			
			lappend awayplayer [lindex [lindex $awaydata $i] 0]
			lappend awayfouls [lindex [lindex $awaydata $i] 13]

			incr i

		}

		set homeplayer [list]
		set homefouls [list]
		set i 1
		while {$i < $homeplayers} {
			
			lappend homeplayer [lindex [lindex $homedata $i] 0]
			lappend homefouls [lindex [lindex $homedata $i] 13]

			incr i

		}

		set awaytrouble ""
		set hometrouble ""

		for {set i 0} {$i < 6} {incr i} {

			set fouls [expr 6 - $i]

			for {set n 0} {$n < [llength $awayplayer]} {incr n} {
				if {[lindex $awayfouls $n] == $fouls} {
					append awaytrouble " [lindex $awayplayer $n] ($fouls);"
				}
			}
		}

		for {set i 0} {$i < 6} {incr i} {

			set fouls [expr 6 - $i]

			for {set n 0} {$n < [llength $homeplayer]} {incr n} {
				if {[lindex $homefouls $n] == $fouls} {
					append hometrouble " [lindex $homeplayer $n] ($fouls);"
				}
			}
		}

		set awaytrouble [string trim $awaytrouble "; "]
		set hometrouble [string trim $hometrouble "; "]

		return [list $awaytrouble $hometrouble]

	}

	# ## ### #### #####
	# Возвращает список со строками с количеством набранных очков
	# для гостевой и домашней команд
	# ## ### #### #####
	proc ::nbascore::PointsLeaders {gameid} {

		set boxscorelist [::nbascore::Boxscore $gameid]

		set awaydata [lindex $boxscorelist 10]
		set homedata [lindex $boxscorelist 11]

		set awayplayers [llength $awaydata]
		set homeplayers [llength $homedata]

		set awayplayer [list]
		set awaypoints [list]

		set pointleader 0

		set i 1
		while {$i < $awayplayers} {
			
			lappend awayplayer [lindex [lindex $awaydata $i] 0]
			set playerpoints [lindex [lindex $awaydata $i] 15]
			lappend awaypoints $playerpoints
			if {$playerpoints > $pointleader} {set pointleader $playerpoints}

			incr i

		}

		set homeplayer [list]
		set homepoints [list]
		set i 1
		while {$i < $homeplayers} {
			
			lappend homeplayer [lindex [lindex $homedata $i] 0]
			set playerpoints [lindex [lindex $homedata $i] 15]
			lappend homepoints $playerpoints
			if {$playerpoints > $pointleader} {set pointleader $playerpoints}

			incr i

		}

		set awayscoreline ""
		set homescoreline ""

		for {set i 0} {$i < $pointleader} {incr i} {

			set points [expr $pointleader - $i]

			for {set n 0} {$n < [llength $awayplayer]} {incr n} {
				if {[lindex $awaypoints $n] == $points} {
					append awayscoreline " [lindex $awayplayer $n] ($points);"
				}
			}

			for {set n 0} {$n < [llength $homeplayer]} {incr n} {
				if {[lindex $homepoints $n] == $points} {
					append homescoreline " [lindex $homeplayer $n] ($points);"
				}
			}
			
		}

		set awayscoreline [string trim $awayscoreline "; "]
		set homescoreline [string trim $homescoreline "; "]

		return [list $awayscoreline $homescoreline]
	}

	# Отнимает день от формы даты 20130209. Вернет 20130208
	proc ::nbascore::Yesterday {today} {
		set year [string range $today 0 3]
		set month [string range $today 4 5]
		set day [string range $today 6 7]
		
		if {$day == 01} {
			if {$month == 01} {
				set month 12
				set year [expr $year - 1]
			} else {
				if {$month < 10} {set month [string index $month 1]}
				set month [expr $month - 1]
			}
			if {$month < 10} {set month 0$month}
			switch -exact -- $month {
				01 {set day 31}
				02 {set day 28}
				03 {set day 31}
				04 {set day 30}
				05 {set day 31}
				06 {set day 30}
				07 {set day 31}
				08 {set day 31}
				09 {set day 30}
				10 {set day 31}
				11 {set day 30}
				12 {set day 31}
				default {set day 30}
			}
		} else {
			if {$day < 10} {set day [string index $day 1]}
			set day [expr $day - 1]
			if {$day < 10} {set day 0$day}
		}
		set date $year$month$day
		return $date
	}

	# Добавляет день к форме даты 20130209. Вернет 20130210
	proc ::nbascore::Tomorrow {today} {

		set year [string range $today 0 3]
		set month [string range $today 4 5]
		set day [string range $today 6 7]

		if {$day < 10} {set day [string index $day 1]}
		set day [expr $day + 1]
		if {$day < 10} {set day 0$day}
		

		if {$day == 29} {
			if {$month == "02"} {
				set month 03
				set day 01
			}
		}
		if {$day == 31} {
			if {$month == "04"} {
				set month 05
				set day 01
			}
			if {$month == "06"} {
				set month 07
				set day 01
			}
			if {$month == "09"} {
				set month 10
				set day 01
			}
			if {$month == "11"} {
				set month 12
				set day 01
			}
		}
		if {$day == "32"} {
			set day "01"
			if {$month < 10} {set month [string index $month 1]}
			set month [expr $month + 1]
			if {$month < 10} {set month 0$month}
			if {$month == "13"} {
				set month "01"
				incr year
			}
		}

		set date $year$month$day
		return $date	
	}

	# ## ### #### #####
	# Вычисляет оставшееся до матча время
	# ## ### #### #####
	proc ::nbascore::TimeRemain {datetime} {
		# разница во времени
		set offset [expr $::nbascore::timeoffset * 3600]

		set gametime [clock scan $datetime]
		set gametime [expr $gametime + $offset]
		set diff [expr $gametime - [clock seconds]]
		if {$diff < 60} {
			return "now"
		}
		set minuts [expr $diff / 60]
		set hours [expr $minuts / 60]
		set minuts [expr $minuts - ($hours * 60)]
		if {$minuts < 10} {
			set minuts 0$minuts
		}

		return "$hours:$minuts"
	}

	# запрос на html. НАПИСАТЬ ОБРАБОТЧИК ИСКЛЮЧИТЕЛЬНЫХ СИТУАЦИЙ!
	proc ::nbascore::HTML {address} {

		putlog "::nbascore::HTML in with $address"

		set htmldata ""

		::http::config -useragent "Mozilla/5.0 (Windows; U; Windows NT 5.2; rv:1.7.3) Gecko/20040913 Firefox/0.10.1"
		set code [catch {set token [::http::geturl $address]} errcode]
		putlog "http::geturl finished with $errcode code"
		putlog "http::geturl code: $code"


		if  {$code == 0} {
			set status [::http::status $token]
			putlog "transfer status: $status"
			set htmldata [::http::data $token]
			putlog "transfer complete, [::http::size $token] received"
			::http::cleanup $token
			if {[string match {http://scores.espn.go.com/nba/playbyplay?*} $address]} {
				set filechan [open test.html w+]
				puts $filechan $htmldata
				close $filechan
			}
		}





		putlog "::nbascore::HTML out with [string length $htmldata] symbols"

		return $htmldata
	}


	# ## ### #### #####
	# ПАРСЕР Playbyplay
	# Параметры: ESPN gameId; "full" для всей игры | "default" для страницы по-умолчанию
	# Возвращает:
	# [list $titleteams $titledate $gamestate $ateam $hteam $ascorelist $aperf $hscorelist $hperf $actionlist]
	#  0 Переменная с названиями команд: Sacramento Kings vs. Miami Heat
	#  1 Переменная с датой игры: February 26, 2013
	#  2 Переменная с типом данных: Boxscore | Play by Play
	#  3 Переменная с состоянием игры: 7:00 PM ET | In Progress * | Final
	#  4 Список с названием гостевой команды: 
	#		0 полное (Boston Celtics) 
	# 		1 только название (Celtics) 
	# 		2 сокращенное (BOS)
	#  5 Список с названием домашней команды аналогично гостевой
	#  6 Список с очками гостевой команды по четвертям и сумма в последнем элементе
	#  7 Список с Top performer гостевой команды: Имя; Показатели
	#  8 Список с очками домашней команды по четвертям и сумма в последнем элементе
	#  9 Список с Top performer домашней команды: Имя; Показатели
	# 10 Список с действиями:
	# 		0 событие: awayscore | awaynoscore | homescore | homenoscore | break | quarterstart
	# 		1 четверть
	# 		2 время
	# 		3 счет
	# 		4 описание
	# ## ### #### #####

	proc ::nbascore::Playbyplay {gameid {page "current"}} {

		putlog "::nbascore::Playbyplay in"

		switch -exact -- $page {
			"full" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=0"
			}
			"1" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=1"	
			}
			"2" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=2"	
			}
			"3" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=3"	
			}
			"4" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=4"	
			}
			"5" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=5"	
			}
			"6" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=6"	
			}
			"7" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=7"	
			}
			"8" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=8"	
			}
			"9" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=9"	
			}
			"10" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid&period=10"	
			}
			"current" {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid"	
			}
			default {
				set address "http://scores.espn.go.com/nba/playbyplay?gameId=$gameid"
			}
		}
		
		set htmldata [::nbascore::HTML $address]

		# убираем переносы строк
		regsub -all -expanded -- {>/s+<} $htmldata "><" htmldata

		# парсим заголовок
		set header [::nbascore::HeaderLight $htmldata]

		# выгребаем gamestate
		set gamestate [lindex $header 3]
		if {[string match {*ET} $gamestate]} {
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay quick out"

			return $result
		}

		if {$gamestate == ""} {
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay quick out with NO GAMESTATE ERROR"

			return $result
		}

		# ACTIONLIST
		# чистим все до таблички
		if {![regsub -expanded -- {.*<h2>[^<]*Play-By-Play</h2>} $htmldata "" htmldata]} {
			
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay-test quick out with NO PLAYBYPLAY TABLE ERROR"
			return $result

		}
		# чистим лишнее после
		if {![regsub -expanded -- {</table></div></div>.*} $htmldata "" htmldata]} {
			
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay-test quick out with NO PLAYBYPLAY TABLE ERROR"
			return $result

		}

		set actionlist [list]

		set onceagain 1
		while {$onceagain} {
			set onceagain [regexp -expanded -- {<tr[^>]*?>(.*?)</tr>} $htmldata match line]
			if {$onceagain} {
				regsub {<tr[^>]*?>(.*?)</tr>} $htmldata "" htmldata

				if {![regexp {</th>} $line match]} {
					if {[regexp {<h4[^>]*>(.*)</h4>} $line match quarterstart]} {
						# начало четверти 
						regsub {\sSummary.*} $quarterstart "" quarterstart
						set quarterstart [string trim $quarterstart]
						switch -exact -- $quarterstart {
							"1st Quarter" {
								set quarter "1"
							}
							"2nd Quarter" {
								set quarter "2"
							}
							"3rd Quarter" {
								set quarter "3"
							}
							"4th Quarter" {
								set quarter "4"
							}
							"1st Overtime" {
								set quarter "1OT"
							}
							"2nd Overtime" {
								set quarter "2OT"
							}
							"3rd Overtime" {
								set quarter "3OT"
							}
							"4th Overtime" {
								set quarter "4OT"
							}
							"5th Overtime" {
								set quarter "5OT"
							}
							"6th Overtime" {
								set quarter "6OT"
							}
							default {
								set quarter "0"
							}
						}
						set time "12:00"
						if {![info exists score]} {set score "0-0"}
						set quarterstart "Start of $quarterstart"
						lappend actionlist [list "quarterstart" $quarter $time $score $quarterstart]
					} else {
						if {[regexp {<td[^>]*?>([^<]*?)</td><td\scolspan="3"\sstyle="text-align:center;"><b>([^<]*?)</b></td>} $line match time reason]} {
							# таймауты, концы четвертей
							lappend actionlist [list "break" $quarter $time $score $reason]
						} else {
							if {[regexp {<td[^>]*>([^<]*)</td><td[^>]*>(.*)</td><td[^>]*>([^<]*)</td><td[^>]*>(.*)</td>} $line match time aaction score haction]} {
								# игровое событие
								if {$aaction == "&nbsp;"} {
									if {[regexp {<B>(.*)</B>} $haction match action]} {
										set event "homescore"
									} else {
										set event "homenoscore"
										set action $haction
									}
								} else {
									if {[regexp {<B>(.*)</B>} $aaction match action]} {
										set event "awayscore"
									} else {
										set event "awaynoscore"
										set action $aaction
									}
								}
								set action [string trim $action]
								lappend actionlist [list $event $quarter $time $score $action]
							}
						}
					}
				}
			}
		}

		set result $header
		lappend result $actionlist

		putlog "::nbascore::Playbyplay out"

		return $result
	}


	# ## ### #### #####
	# ПАРСЕР Boxscore
	# Параметр - ESPN gameId 
	# Возвращает:
	#  0 Переменная с названиями команд: Sacramento Kings vs. Miami Heat
	#  1 Переменная с датой игры: February 26, 2013
	#  2 Переменная с типом данных: Boxscore | Play by Play
	#  3 Переменная с состоянием игры: 7:00 PM ET | In Progress * | Final
	#  4 Список с названием гостевой команды: полное; только название (Celtics); сокращенное (BOS)
	#  5 Список с названием домашней команды: полное; только название (Celtics); сокращенное (BOS)
	#  6 Список с очками гостевой команды по четвертям и сумма в последнем элементе
	#  7 Список с Top performer гостевой команды: Имя; Показатели
	#  8 Список с очками домашней команды по четвертям и сумма в последнем элементе
	#  9 Список с Top performer домашней команды: Имя; Показатели
	# 10 Список со статистикой гостевой команды:
	# 	Нулевой элемент списка - список с командной статистикой:
	# 		 0 броски с игры точно-попытки
	# 		 1 3-очковые точно-попытки
	# 		 2 штрафные точно-попытки
	# 		 3 подборы в нападении
	# 		 4 подборы в защите
	# 		 5 сумма подборов
	# 		 6 передачи
	# 		 7 перехваты
	# 		 8 блокшоты
	# 		 9 потери
	# 		10 персональные замечания
	# 		11 очки
	# 		12 процент попадения с игры
	# 		13 процент попадения с 3-очковой
	# 		14 процент попадения со штрафной
	# 		15 очки в быстром прорыве
	# 		16 очки из трехсекундной
	# 		17 общее число потерь (очки от потерь)
	# 	Далее персональная статистика по списку на каждого принимавшего участие игрока:
	# 		 0 имя
	# 		 1 позиция
	# 		 2 сыгранные минуты
	# 		 3 броски с игры точно-попытки
	# 		 4 броски с 3-очковой точно-попытки
	# 		 5 броски с штрафной точно-попытки
	# 		 6 подборы в нападении
	# 		 7 подборы в защите
	# 		 8 сумма подборов
	# 		 9 передачи
	# 		10 перехваты
	# 		11 блокшоты
	# 		12 потери
	# 		13 персональные замечания
	# 		14 полезность
	# 		15 очки
	#  11 Список со статистикой домашней команды. Содержание списка аналогично
	# ## ### #### #####
	proc ::nbascore::Boxscore {gameid} {
		
		set address "http://scores.espn.go.com/nba/boxscore?gameId=$gameid"

		set htmldata [::nbascore::HTML $address]

		# убираем переносы строк
		regsub -all -expanded -- {>/s+<} $htmldata "><" htmldata

		# парсим заголовок
		set header [::nbascore::Header $htmldata]

		# выгребаем gamestate
		set gamestate [lindex $header 3]
		if {[string match {*ET} $gamestate]} {
			return 0
		}

		regexp -expanded -- {<tr\sclass="team-color-strip">.*?</div></td></tr></tbody>} $htmldata awaydata
		regsub {<tr\sclass="team-color-strip">.*?</div></td></tr></tbody>} $htmldata "" htmldata
		set awaystat [::nbascore::Boxscoretable $awaydata]

		regexp -expanded -- {<tr\sclass="team-color-strip">.*?</div></td></tr></tbody>} $htmldata homedata
		set homestat [::nbascore::Boxscoretable $homedata]

		set result $header
		lappend result $awaystat
		lappend result $homestat
		return $result
	}

	proc ::nbascore::Boxscoretable {htmldata} {
		set data $htmldata
		set stayin 1
		set personalstat [list]
		set teamstat [list]
		while {$stayin} {
			# Получаем строку таблицы
			set stayin [regexp {<tr[^>]*?>(.*?)</tr>} $data match line]
			if {$stayin} {
				# Удаляем эту строку из данных парсинга
				regsub {<tr[^>]*?>(.*?)</tr>} $data "" data
				if {[regexp {<td[^>]*?><a[^>]*?>([^<]*?)</a>,\s+([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td><td[^>]*?>([^<]*)</td>} \
							$line match player pos min fgma tpma ftma oreb dreb reb ast stl blk to pf usef pts]} {
					set playerstat [list $player $pos $min $fgma $tpma $ftma $oreb $dreb $reb $ast $stl $blk $to $pf $usef $pts]
					lappend personalstat $playerstat
						
				} else {
					if {[regexp {<td[^>]*></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td>&nbsp;</td><td><strong>([^<]*)</strong></td>} \
								$line match tfgma ttpma ttfma toreb tdreb treb tast tstl tblk tto tpf tpts]} {
						# пустое место говнокода
					} else {
						if {[regexp {<td[^>]*><strong></strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td><td><strong>([^<]*)</strong></td>} $line match tfgperc ttpperc tftperc]} {
							# пустое место говнокода
						} else {
							regsub -all -- {&nbsp;} $line "" line
							if {[regexp {<td[^>]*><div[^>]*><strong>Fast[^<]*</strong>([^<]*)<br\s/><strong>Points[^<]*</strong>([^<]*)<br\s/><strong>Total[^<]*</strong>([^<]*)} $line match fastbreak paint turnover]} {
								# пустое место говнокода
							}
						}
					}
				}	
			} 
		}
		set teamstat [list $tfgma $ttpma $ttfma $toreb $tdreb $treb $tast $tstl $tblk $tto $tpf $tpts $tfgperc $ttpperc $tftperc $fastbreak $paint $turnover]
		return [linsert $personalstat 0 $teamstat]
	}

	# Возвращает строку статистики игрока
	proc ::nbascore::Playerstats {playerdata} {
		# $player $pos $min $fgma $tpma $ftma $oreb $dreb $reb $ast $stl $blk $to $pf $usef $pts
		set player [lindex $playerdata 0]
		set pos [lindex $playerdata 1]
		set min [lindex $playerdata 2]
		set fgma [lindex $playerdata 3]
		set tpma [lindex $playerdata 4]
		set ftma [lindex $playerdata 5]
		set oreb [lindex $playerdata 6]
		set dreb [lindex $playerdata 7]
		set reb [lindex $playerdata 8]
		set ast [lindex $playerdata 9]
		set stl [lindex $playerdata 10]
		set blk [lindex $playerdata 11]
		set to [lindex $playerdata 12]
		set pf [lindex $playerdata 13]
		set usef [lindex $playerdata 14] 
		set pts [lindex $playerdata 15]
		set line "\002$player\002: $min Min, \002$pts\002 Pts"
		if {$fgma != "0-0"} {
			append line ", $fgma FG"
		}
		if {$tpma != "0-0"} {
			append line ", $tpma 3P"
		}
		if {$ftma != "0-0"} {
			append line ", $ftma FT"
		}
		if {$ast != "0"} {
			append line ", \002$ast\002 Ast"
		}
		if {$reb != "0"} {
			append line ", \002$reb\002 Reb"
		}
		if {$stl != "0"} {
			append line ", $stl Stl"
		}
		if {$blk != "0"} {
			append line ", $blk Blk"
		}
		if {$to != "0"} {
			append line ", $to TO"
		}
		if {$pf != "0"} {
			append line ", $pf Fouls"
		}
		return $line
	}

		# Возвращает строку статистики игрока
	proc ::nbascore::teamStats {teamdata} {
		# $tfgma $ttpma $ttfma $toreb $tdreb $treb $tast $tstl $tblk $tto $tpf $tpts $tfgperc $ttpperc $tftperc $fastbreak $paint $turnover
		set tfgma [lindex $teamdata 0]
		set ttpma [lindex $teamdata 1]
		set tftma [lindex $teamdata 2]
		set toreb [lindex $teamdata 3]
		set tdreb [lindex $teamdata 4]
		set treb [lindex $teamdata 5]
		set tast [lindex $teamdata 6]
		set tstl [lindex $teamdata 7]
		set tblk [lindex $teamdata 8]
		set tto [lindex $teamdata 9]
		set tpf [lindex $teamdata 10]
		set tpts [lindex $teamdata 11]
		set tfgperc [lindex $teamdata 12]
		set ttpperc [lindex $teamdata 13]
		set tftperc [lindex $teamdata 14]
		set fastbreak [lindex $teamdata 15] 
		set paint [lindex $teamdata 16]
		set turnover [lindex $teamdata 17]
		
		set line "FG $tfgma ($tfgperc), "
		
		append line "3P $ttpma ($ttpperc), "
		
		append line "FT $tftma ($tftperc), "
		append line "Ast $tast, "
		append line "Reb $toreb+$tdreb=$treb, "
		append line "Stl $tstl, "
		append line "Blk $tblk, "
		append line "TO $turnover, "
		append line "Fast Break $fastbreak Pts, "
		append line "in Paint $paint Pts"
		
		return $line
	}

	# ## ### #### #####
	# ПАРСЕР ЗАГОЛОВКА
	# Параметр: переменная с содержимым html
	# Возвращает:
	# [list $titleteams $titledate $gamestate $ateam $hteam $ascorelist $aperf $hscorelist $hperf]
	# 0 Переменная с названиями команд: Sacramento Kings vs. Miami Heat
	# 1 Переменная с датой игры: February 26, 2013
	# 2 Переменная с типом данных: Boxscore | Play by Play
	# 3 Переменная с состоянием игры: 7:00 PM ET | In Progress * | Final
	# 4 Список с названием гостевой команды: полное; только название (Celtics); сокращенное (BOS)
	# 5 Список с названием домашней команды: полное; только название (Celtics); сокращенное (BOS)
	# 6 Список с очками гостевой команды по четвертям и сумма в последнем элементе
	# 7 Список с Top performer гостевой команды: Имя; Показатели
	# 8 Список с очками домашней команды по четвертям и сумма в последнем элементе
	# 9 Список с Top performer домашней команды: Имя; Показатели
	# ## ### #### #####
	proc ::nbascore::Header {htmldata} {

		# TITLE
		# <title>Sacramento Kings vs. Miami Heat - Play By Play - February 26, 2013 - ESPN</title>
		regexp -expanded -- {<title>(.*)</title>} $htmldata match title
		regexp -expanded -- {([^-]*)-([^-]*)-([^-]*)-} $title match titleteams datatype titledate

		set titleteams [string trim $titleteams]
		set titledate [string trim $titledate]
		set datatype [string trim $datatype]
		regexp {(.*)vs.(.*)} $titleteams match ateamlong hteamlong
		set ateamlong [string trim $ateamlong]
		set hteamlong [string trim $hteamlong]

		regexp {<div\sclass="team\saway"><div[^>]*></div><div[^>]*><h3[^>]*><a[^>]*>([^<]*)</a>} $htmldata match ateamlast
		regexp {<div\sclass="team\shome"><div[^>]*></div><div[^>]*><h3[^>]*><a[^>]*>([^<]*)</a>} $htmldata match hteamlast	

		# GAMESTATE
		if {![regexp -expanded -- {class="game-state">([^<]*)<} $htmldata match gamestate]} {return}

		if {[string match {*ET} $gamestate]} {
			set aperf [list]
			set hperf [list]
			set ascorelist [list]
			set hscorelist [list]

			set ateam [list $ateamlong $ateamlast]
			set hteam [list $hteamlong $hteamlast]
			
		} else {

			# TOP PERFORMERS
			regexp -expanded -- {<div\sclass="game-notes">(.*?)</div>} $htmldata match perf

			if {[regexp -expanded -- {<span>Top\sPerformers</span></p><p><span>([^<]*):\s*</span><a[^>]*>([^<]*)</a>([^<]*)</p><p><span>([^<]*):\s*</span><a[^>]*>([^<]*)</a>([^<]*)</p>} $htmldata \
				match ateamcity aplayer aperf hteamcity hplayer hperf]} {
				set aperf [string trim $aperf]
				set hperf [string trim $hperf]

				set aperf [list $aplayer $aperf]
				set hperf [list $hplayer $hperf]

			} else {
				putlog "Gamestat: No Match Top Performers"
				set aperf [list]
				set hperf [list]
			}

			# SCOREBOX
			regexp {<tr class="periods">.*?</table>} $htmldata parsedata
			regsub -all {</td><td[^>]*>} $parsedata " " parsedata
			regexp {<a\shref=[^>]*>([^<]*)</a>([^<]*)} $parsedata match ateamshort ascore
			regsub {<a\shref=[^>]*>[^<]*</a>[^<]*} $parsedata " " parsedata
			regexp {<a\shref=[^>]*>([^<]*)</a>([^<]*)} $parsedata match hteamshort hscore
			regsub -all {\s+} $ascore " " ascore
			regsub -all {\s+} $hscore " " hscore
			set ascore [string trim $ascore]
			set hscore [string trim $hscore]

			set ateam [list $ateamlong $ateamlast $ateamshort]
			set hteam [list $hteamlong $hteamlast $hteamshort]

			set ascorelist [split $ascore " "]
			set hscorelist [split $hscore " "]

		}

		return [list $titleteams $titledate $datatype $gamestate $ateam $hteam $ascorelist $aperf $hscorelist $hperf]
	}




	# ## ### #### #####
	# ПАРСЕР ЗАГОЛОВКА УПРОЩЕННЫЙ
	# Параметр: переменная с содержимым html
	# Возвращает:
	# [list $titleteams $titledate $gamestate $ateam $hteam $ascorelist $aperf $hscorelist $hperf]
	# 0 Переменная с названиями команд: Sacramento Kings vs. Miami Heat
	# 1 Переменная с датой игры: February 26, 2013
	# 2 Переменная с типом данных: Boxscore | Play by Play
	# 3 Переменная с состоянием игры: 7:00 PM ET | In Progress * | Final
	# 4 Список с названием гостевой команды: полное; только название (Celtics)
	# 5 Список с названием домашней команды: полное; только название (Celtics)
	# ## ### #### #####
	proc ::nbascore::HeaderLight {htmldata} {

		putlog "::nbascore::HeaderLight in"

		# TITLE
		# <title>Sacramento Kings vs. Miami Heat - Play By Play - February 26, 2013 - ESPN</title>
		set title ""
		set titleteams ""
		set datatype ""
		set titledate ""
		set ateamlong ""
		set hteamlong ""
		set gamestate ""
		set ateamlast ""
		set hteamlast ""


		regexp -expanded -- {<title>(.*)</title>} $htmldata match title
		regexp -expanded -- {([^-]*)-([^-]*)-([^-]*)-} $title match titleteams datatype titledate

		set titleteams [string trim $titleteams]
		set titledate [string trim $titledate]
		set datatype [string trim $datatype]
		regexp {(.*)vs.(.*)} $titleteams match ateamlong hteamlong
		set ateamlong [string trim $ateamlong]
		set hteamlong [string trim $hteamlong]

		regexp {<div\sclass="team\saway"><div[^>]*></div><div[^>]*><h3[^>]*><a[^>]*>([^<]*)</a>} $htmldata match ateamlast
		regexp {<div\sclass="team\shome"><div[^>]*></div><div[^>]*><h3[^>]*><a[^>]*>([^<]*)</a>} $htmldata match hteamlast	

		# GAMESTATE
		if {![regexp -expanded -- {class="game-state">([^<]*)<} $htmldata match gamestate]} {return}


		set ateam [list $ateamlong $ateamlast]
		set hteam [list $hteamlong $hteamlast]
			
		putlog "::nbascore::HeaderLight out"

		return [list $titleteams $titledate $datatype $gamestate $ateam $hteam]
	}


	# ## ### #### #####
	# ПАРСЕР  Standings
	# Параметров нет
	# Возвращает 2 списка: восточная конференция, западная конференция
	# в каждой по 15 списков по команде в порядке положения в конференции
	# в каждом из списков переменные:
	# 	 0 место (для первых 8-ми)
	# 	 1 название команды
	# 	 2 побед
	# 	 3 поражений
	# 	 4 процент побед
	# 	 5 позади лидера конференции
	# 	 6 домашний баланс
	# 	 7 гостевой баланс
	# 	 8 баланс в дивизионе
	# 	 9 баланс в конференции
	# 	10 средние забитые
	# 	11 средние пропущенные
	# 	12 средняя разница
	# 	13 текущая серия
	# 	14 баланс последних десяти игр
	# ## ### #### #####
	proc ::nbascore::Standings {} {
		set htmldata [::nbascore::HTML http://espn.go.com/nba/standings]

		if {[regexp {<table\sclass="tablehead".*</table>} $htmldata table]} {

			# убираем переносы строк
			regsub -all -expanded -- {>\s+<} $table "><" table

			set onceagain 1
			# тестовый список со строками
			set lines [list]


			set eastern [list]
			set western [list]
			while {$onceagain} {
				set onceagain [regexp -expanded -- {<tr[^>]*?>(.*?)</tr>} $table match line]
				if {$onceagain} {
					regsub {<tr[^>]*?>(.*?)</tr>} $table "" table

					# тестовый список со строками
					lappend lines $line

					if {[regexp {Eastern\sConference} $line match]} {
						set conference "east"
					}
					if {[regexp {Western\sConference} $line match]} {
						set conference "west"
					}

					if {[regexp -expanded -- {<td>([^<]*)</td><td[^>]*>[^<]*<a[^>]*>([^<]*)</a></td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td>([^<]*)</td><td><span[^>]*>([^<]*)</span></td><td>([^<]*)</td><td>([^<]*)</td>} \
					 $line match place team wins losses pct gb home road div conf pf pa diff streak last10]} {
					 	switch -exact -- $conference {
					 		"east" {
					 			lappend eastern [list $place $team $wins $losses $pct $gb $home $road $div $conf $pf $pa $diff $streak $last10]
					 		}
					 		"west" {
					 			lappend western [list $place $team $wins $losses $pct $gb $home $road $div $conf $pf $pa $diff $streak $last10]
					 		}
					 		default {}
					 	}
					}
				}

			}
			return [list $eastern $western]
		}
	}


	# ## ### #### #####
	# ПАРСЕР  Scoreboard
	# Параметр - дата в формате 20130329
	# Возвращает список 
	# Нулевой элемент - список с датой
	# 	0 день
	# 	1 месяц на английском
	# 	2 год
	# 	3 дата в формате 20130329
	# Далее по списку на каждый матч дня. В каждом списке матча:
	# 	0 gameId
	# 	1 состояние игры
	# 	2 короткое название гостевой команды (BOS)
	# 	3 длинное название гостевой команды (Boston Celtics)
	# 	4 название гостевой команды (Celtics)
	# 	5 количество очков, набранных гостевой командой
	# 	6 короткое название домашней команды (BOS)
	# 	7 длинное название домашней команды (Boston Celtics)
	# 	8 название домашней команды (Celtics)
	# 	9 количество очков, набранных домашней командой 
	# ## ### #### #####
	proc ::nbascore::Scoreboard {{date "today"}} {
		
		switch -exact -- $date {
			"today" {
				set address "http://scores.espn.go.com/nba/scoreboard"
			}
			default {
				set address "http://scores.espn.go.com/nba/scoreboard?date=$date"
			}
		}

		set htmldata [::nbascore::HTML $address]

		set scoreboard [list]

		if {[regexp -expanded -- {Scores\sfor\s(\w+)\s(\d|\d\d),\s(\d\d\d\d)</h2} $htmldata \
				match month day year]} {
			switch -exact -- $month {
				January {
					set smonth 01
				}
				February {
					set smonth 02	
				}
				March {
					set smonth 03
				}
				April {
					set smonth 04
				}
				May {
					set smonth 05
				}
				June {
					set smonth 06
				}
				July {
					set smonth 07
				}
				August {
					set smonth 08
				}
				September {
					set smonth 09
				}
				October {
					set smonth 10
				}
				November {
					set smonth 11
				}
				December {
					set smonth 12
				}
				default {
					set smonth 01
				}
			}
			if {$day < 10} {
				set longday 0$day
			} else {
				set longday $day
			}
			set fulldate $year$smonth$longday

			lappend scoreboard [list $day $month $year $fulldate]
		}	

		if {[regexp -expanded -- {\s0-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s1-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s2-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s3-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s4-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s5-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s6-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s7-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s8-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s9-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s10-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s11-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s12-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s13-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}
		if {[regexp -expanded -- {\s14-gameCount.+?(\d\d\d\d\d\d\d\d\d)-statusLine1">(.+)</p>.+?statusLine2.+?-aTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<.+?hTeamName"><a\shref=.http://espn\.go\.com/nba/team/_/name/([^/]+)/([^"]+)">([^<]+?)<.+?finalScore">([^<]+)<} $htmldata \
				match gameid status ateamshort ateamlong ateam ascore hteamshort hteamlong hteam hscore]} {
			set ateamshort [string toupper $ateamshort]
			set hteamshort [string toupper $hteamshort]
			lappend scoreboard [list $gameid $status $ateamshort $ateamlong $ateam $ascore $hteamshort $hteamlong $hteam $hscore]
		}

		return $scoreboard
	} 

	proc ::nbascore::LongToShort {teamlong} {
		switch -exact -- $teamlong {
			"Boston Celtics" {
				set teamshort "BOS"
			}
			"Brooklyn Nets" {
				set teamshort "BKN"
			}
			"Philadlphia 76ers" {
				set teamshort "PHI"
			}
			"New York Knicks" {
				set teamshort "NYK"
			}
			"Toronto Raptors" {
				set teamshort "TOR"
			}
			"Chicago Bulls" {
				set teamshort "CHI"
			}
			"Cleveland Cavaliers" {
				set teamshort "CLE"
			}
			"Detroit Pistons" {
				set teamshort "DET"
			}
			"Indiana Pacers" {
				set teamshort "IND"
			}
			"Milwaukee Bucks" {
				set teamshort "MIL"
			}
			"Atlanta Hawks" {
				set teamshort "ATL"
			}
			"Charlotte Bobcats" {
				set teamshort "CHA"
			}
			"Miami Heat" {
				set teamshort "MIA"
			}
			"Orlando Magic" {
				set teamshort "ORL"
			}
			"Washington Wizards" {
				set teamshort "WSH"
			}
			"Golden State Warriors" {
				set teamshort "GSW"
			}
			"Los Angeles Clippers" {
				set teamshort "LAC"
			}
			"Los Angeles Lakers" {
				set teamshort "LAL"
			}
			"Phoenix Suns" {
				set teamshort "PHX"
			}
			"Sacramento Kings" {
				set teamshort "SAC"
			}
			"Dallas Mavericks" {
				set teamshort "DAL"
			}
			"Houston Rockets" {
				set teamshort "HOU"
			}
			"Memphis Grizzlies" {
				set teamshort "MEM"
			}
			"New Orleans Hornets" {
				set teamshort "NOH"
			}
			"San Antonio Spurs" {
				set teamshort "SAS"
			}
			"Denver Nuggets" {
				set teamshort "DEN"
			}
			"Minnesota Timberwolves" {
				set teamshort "MIN"
			}
			"Oklahoma City Thunder" {
				set teamshort "OKC"
			}
			"Portland Trail Blazers" {
				set teamshort "POR"
			}
			"Utah Jazz" {
				set teamshort "UTAH"
			}
			
			default {set teamshort "???"}
		}

		return $teamshort
	}


	proc ::nbascore::Playbyplay-test {address} {

		putlog "::nbascore::Playbyplay-test in"
		
		set htmldata [::nbascore::HTML $address]

		# убираем переносы строк
		regsub -all -expanded -- {>/s+<} $htmldata "><" htmldata

		# парсим заголовок
		set header [::nbascore::HeaderLight $htmldata]

		# выгребаем gamestate
		set gamestate [lindex $header 3]
		if {[string match {*ET} $gamestate]} {
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay quick out"

			return $result
		}

		if {$gamestate == ""} {
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay quick out with NO GAMESTATE ERROR"

			return $result
		}

		# ACTIONLIST
		# чистим все до таблички
		if {![regsub -expanded -- {.*<h2>[^<]*Play-By-Play</h2>} $htmldata "" htmldata]} {
			
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay-test quick out with NO PLAYBYPLAY TABLE ERROR"
			return $result

		}
		# чистим лишнее после
		if {![regsub -expanded -- {</table></div></div>.*} $htmldata "" htmldata]} {
			
			set result $header
			lappend result [list]

			putlog "::nbascore::Playbyplay-test quick out with NO PLAYBYPLAY TABLE ERROR"
			return $result

		}

		set actionlist [list]

		set onceagain 1
		while {$onceagain} {
			set onceagain [regexp -expanded -- {<tr[^>]*?>(.*?)</tr>} $htmldata match line]
			# putlog "onceagain: $onceagain"
			if {$onceagain} {
				# putlog "line: $line"
				regsub {<tr[^>]*?>(.*?)</tr>} $htmldata "" htmldata

				if {![regexp {</th>} $line match]} {
					if {[regexp {<h4[^>]*>(.*)</h4>} $line match quarterstart]} {
						
						# начало четверти 
						regsub {\sSummary.*} $quarterstart "" quarterstart
						set quarterstart [string trim $quarterstart]
						switch -exact -- $quarterstart {
							"1st Quarter" {
								set quarter "1"
							}
							"2nd Quarter" {
								set quarter "2"
							}
							"3rd Quarter" {
								set quarter "3"
							}
							"4th Quarter" {
								set quarter "4"
							}
							"1st Overtime" {
								set quarter "1OT"
							}
							"2nd Overtime" {
								set quarter "2OT"
							}
							"3rd Overtime" {
								set quarter "3OT"
							}
							"4th Overtime" {
								set quarter "4OT"
							}
							"5th Overtime" {
								set quarter "5OT"
							}
							"6th Overtime" {
								set quarter "6OT"
							}
							default {
								set quarter "0"
							}
						}

						set time "12:00"
						if {![info exists score]} {set score "0-0"}
						set quarterstart "Start of $quarterstart"
						lappend actionlist [list "quarterstart" $quarter $time $score $quarterstart]

					} else {

						if {[regexp {<td[^>]*?>([^<]*?)</td><td\scolspan="3"\sstyle="text-align:center;"><b>([^<]*?)</b></td>} $line match time reason]} {
							
							# таймауты, концы четвертей
							lappend actionlist [list "break" $quarter $time $score $reason]

						} else {
							if {[regexp {<td[^>]*>([^<]*)</td><td[^>]*>(.*)</td><td[^>]*>([^<]*)</td><td[^>]*>(.*)</td>} $line match time aaction score haction]} {
								
								# игровое событие
								if {$aaction == "&nbsp;"} {
									if {[regexp {<B>(.*)</B>} $haction match action]} {
										set event "homescore"
									} else {
										set event "homenoscore"
										set action $haction
									}
								} else {
									if {[regexp {<B>(.*)</B>} $aaction match action]} {
										set event "awayscore"
									} else {
										set event "awaynoscore"
										set action $aaction
									}
								}
								set action [string trim $action]
								lappend actionlist [list $event $quarter $time $score $action]

							}
						}
					}
				}
			}
		}

		set result $header
		lappend result $actionlist

		putlog "::nbascore::Playbyplay-test out"

		return $result
	}


	putlog "nbascore.tcl ver. 1.0.0 loaded"

}

