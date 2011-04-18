#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(int argc, char* argv[]){
    FILE* northwesternfile;
    char line[120];

    northwesternfile = fopen(argv[1], "rt");

    while(fgets(line, 120, northwesternfile) != NULL){
        while(fgets(line, 120, northwesternfile) != NULL && strlen(line) > 1){
            unsigned long u = strtoul(line, NULL, 10);
            struct in_addr address;
            address.s_addr =  htonl(u); 
            printf("%s ", inet_ntoa(address));
        }
        printf("\n");
        
    }
    return 0;
}
