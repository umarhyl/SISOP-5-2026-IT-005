int cursor = 0;
char color = 0x07;

void putInMemory(int segment, int address, char character);
int getChar();

void printChar(char c);
void printString(char* str);
void clearScreen();
void readString(char* buffer);
int strcmp(char* a, char* b);
int startsWith(char* str, char* prefix);
int atoi(char* str);
void intToString(int num, char* str);
int factorial(int n);
void newline();
void setColor(char c);
void printColored(char* str, char c);

void printChar(char c) {

    int temp;

    if (c == '\n') {

        while (1) {

            temp = cursor;

            while (temp >= 160) {
                temp = temp - 160;
            }

            if (temp == 0) {
                break;
            }

            cursor = cursor + 2;
        }

        return;
    }

    putInMemory(0xB800, cursor, c);
    putInMemory(0xB800, cursor + 1, color);

    cursor = cursor + 2;
}

void printString(char* str) {

    int i = 0;

    while (str[i] != 0) {

        printChar(str[i]);
        i++;
    }
}

void clearScreen() {

    int i = 0;

    while (i < 4000) {

        putInMemory(0xB800, i, ' ');
        putInMemory(0xB800, i + 1, color);

        i = i + 2;
    }

    cursor = 0;
}

void readString(char* buffer) {

    int i = 0;
    char c;

    while (1) {

        c = getChar();

        if (c == 0x0D) {

            buffer[i] = 0;
            break;
        }

        if (c == 0x08) {

            if (i > 0) {

                i = i - 1;
                cursor = cursor - 2;

                printChar(' ');

                cursor = cursor - 2;
            }

            continue;
        }

        buffer[i] = c;
        i++;

        printChar(c);
    }
}

int strcmp(char* a, char* b) {

    int i = 0;

    while (a[i] != 0 && b[i] != 0) {

        if (a[i] != b[i]) {
            return 0;
        }

        i++;
    }

    if (a[i] == b[i]) {
        return 1;
    }

    return 0;
}

int startsWith(char* str, char* prefix) {

    int i = 0;

    while (prefix[i] != 0) {

        if (str[i] != prefix[i]) {
            return 0;
        }

        i++;
    }

    return 1;
}

int atoi(char* str) {

    int result = 0;
    int i = 0;

    while (str[i] != 0) {

        result = result * 10;
        result = result + (str[i] - '0');

        i++;
    }

    return result;
}

void intToString(int num, char* str) {

    int digit;
    int idx = 0;

    if (num == 0) {

        str[0] = '0';
        str[1] = 0;

        return;
    }

    digit = 0;

    while (num >= 10000) {
        num = num - 10000;
        digit++;
    }

    if (digit > 0) {
        str[idx] = digit + '0';
        idx++;
    }

    digit = 0;

    while (num >= 1000) {
        num = num - 1000;
        digit++;
    }

    if (digit > 0 || idx > 0) {
        str[idx] = digit + '0';
        idx++;
    }

    digit = 0;

    while (num >= 100) {
        num = num - 100;
        digit++;
    }

    if (digit > 0 || idx > 0) {
        str[idx] = digit + '0';
        idx++;
    }

    digit = 0;

    while (num >= 10) {
        num = num - 10;
        digit++;
    }

    if (digit > 0 || idx > 0) {
        str[idx] = digit + '0';
        idx++;
    }

    str[idx] = num + '0';
    idx++;

    str[idx] = 0;
}

int factorial(int n) {

    int result = 1;
    int i = 1;

    while (i <= n) {

        result = result * i;
        i++;
    }

    return result;
}

void newline() {
    printChar('\n');
}

void setColor(char c) {
    color = c;
}

void printColored(char* str, char c) {

    setColor(c);

    printString(str);
}

void main() {

    char cmd[64];

    char num1[16];
    char num2[16];

    char out[32];

    int i;
    int j;

    int a;
    int b;

    int n;
    int result;

    clearScreen();

    printString("Welcome to Assistant's Last Gift");

    newline();

    printString("type 'help'");

    newline();
    newline();

    while (1) {

        printString("> ");

        readString(cmd);

        newline();

        if (strcmp(cmd, "check")) {

            printString("ok");
        }

        else if (startsWith(cmd, "add ")) {

            i = 4;
            j = 0;

            while (cmd[i] != ' ' && cmd[i] != 0) {

                num1[j] = cmd[i];

                i++;
                j++;
            }

            num1[j] = 0;

            i++;
            j = 0;

            while (cmd[i] != 0) {

                num2[j] = cmd[i];

                i++;
                j++;
            }

            num2[j] = 0;

            a = atoi(num1);
            b = atoi(num2);

            result = a + b;

            intToString(result, out);

            printString(out);
        }

        else if (startsWith(cmd, "sub ")) {

            i = 4;
            j = 0;

            while (cmd[i] != ' ' && cmd[i] != 0) {

                num1[j] = cmd[i];

                i++;
                j++;
            }

            num1[j] = 0;

            i++;
            j = 0;

            while (cmd[i] != 0) {

                num2[j] = cmd[i];

                i++;
                j++;
            }

            num2[j] = 0;

            a = atoi(num1);
            b = atoi(num2);

            result = a - b;

            intToString(result, out);

            printString(out);
        }

        else if (startsWith(cmd, "fac ")) {

            i = 4;
            j = 0;

            while (cmd[i] != 0) {

                num1[j] = cmd[i];

                i++;
                j++;
            }

            num1[j] = 0;

            n = atoi(num1);

            if (n > 7) {

                printString("know your limit little bro.");
            }

            else {

                result = factorial(n);

                intToString(result, out);

                printString(out);
            }
        }

        else if (strcmp(cmd, "season winter")) {

            printColored("winter mode", 0x09);
        }

        else if (strcmp(cmd, "season spring")) {

            printColored("spring mode", 0x0A);
        }

        else if (strcmp(cmd, "season summer")) {

            printColored("summer mode", 0x0E);
        }

        else if (strcmp(cmd, "season fall")) {

            printColored("fall mode", 0x06);
        }

        else if (strcmp(cmd, "season radiant")) {

            printColored("radiant mode", 0x0D);
        }

        else if (startsWith(cmd, "triangle ")) {

            i = 9;
            j = 0;

            while (cmd[i] != 0) {

                num1[j] = cmd[i];

                i++;
                j++;
            }

            num1[j] = 0;

            n = atoi(num1);

            i = 1;

            while (i <= n) {

                j = 0;

                while (j < i) {

                    printChar('x');

                    j++;
                }

                newline();

                i++;
            }
        }

        else if (strcmp(cmd, "clear")) {

            color = 0x07;

            clearScreen();
        }

        else if (strcmp(cmd, "help")) {

            printString("check add sub fac season triangle clear about");
        }

        else if (strcmp(cmd, "about")) {

            printString("Assistant's Last Gift by MINT");
        }

        else {

            printString("unknown command");
        }

        newline();
    }
}
