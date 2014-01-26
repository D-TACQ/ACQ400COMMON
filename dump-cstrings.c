#include <stdio.h>


int SKIP = 4;
int MAXBYTES = 0x10000;

int dump(FILE* fp)
{
	int ii;
	int zeros = 0;

	for (ii = 0; ii < MAXBYTES; ++ii){
		int ch;
		if ((ch = fgetc(fp)) == EOF){
			break;
		}else if (ii < SKIP){
			continue;
		}else if (ch == '\0'){
			if (zeros++ == 0){
				putchar('\n');
			}else if (zeros > 1){
				break;
			}
		}else{
			putchar(ch);
			zeros = 0;
		}
	}
	return 0;
}

int main(int argc, char* argv[])
{
	if (getenv("SKIP")){
		SKIP = atoi(getenv("SKIP"));
	}	
	if (argc > 1){
		FILE* fp = fopen(argv[1], "r");
		if (fp == 0){
			perror(argv[1]);
		}
		return dump(fp);
	}else{
		return dump(stdin);
	}
}
