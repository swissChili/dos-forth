			..............................................
			... 									   ...
			...             : DOS FORTH ;			   ...
			... 									   ...
			..............................................


This is my attempt at a FORTH implementation in 8086 Assembler for
Microsoft DOS.



							HOW TO COMPILE

Run `make' on a UNIX host system with NASM installed.



							  HOW TO RUN

Run `make run' to start DOSBox automatically, or run FORTH.COM on a
real MS DOS machine or emulator.



							DOCUMENTATION

Please consult <WORDS.TXT> for a list of words and their use.



						IMPLEMENTATION DETAILS

The structure of a dictionary entry is shown in Fig. 1.

				 +--------+-------------------------+
				 |Byte    |Field name               |
				 +--------+-------------------------+
				 |0-1     |Link pointer             |
				 +--------+-------------------------+
				 |2       |Length                   |
				 +--------+-------------------------+
				 |3..N    |Name                     |
				 +--------+-------------------------+
				 |N+1..   |Body (aligned to 2 bytes)|
				 +--------+-------------------------+
					   Fig. 1: Dictionary entry




		Copyright (C) 2021 swissChili -- http://swisschili.sh
