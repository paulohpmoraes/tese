##
## An�lise dos dados dos at�grafos
##

rm(list=ls())  # Remove todos os objetos
arqresults <- "atigrafia.csv"
setwd("C:/Users/Paulo/Google Drive/Doutorado/Actigraphy/Export")
arquivos <- list.files(pattern = "\\.txt$")

WAKEthreshold   <- 40
MOBILEthreshold <- 0

df <- data.frame(Subject=character(),   # Nome do sujeito
                 tEpochs=integer(),     # N�mero de �pocas coletadas
                 nRemoved=integer(),    # N�mero de �pocas removidas
                 
                 nEpochs=integer(),     # N�mero de �pocas restantes
                 mAC=double(),          # M�dia de todos os ACs
                 sdAC=double(),         # Desvio padr�o de todos os ACs
                 pMOBILE=double(),      # Percentual de �pocas classificadas como MOBILE     
                 pWAKE=double(),        # Percentual de �pocas classificadas como WAKE
                 
                 nACTIVE=integer(),     # N�mero de �pocas classificadas como ACTIVE
                 A_mAC=double(),        # M�dia dos ACs no per�odo ACTIVE
                 A_sdAC=double(),       # Desvio padr�o dos ACs no per�odo ACTIVE
                 A_pMOBILE=double(),    # Percentual de �pocas classificadas como MOBILE no per�odo ACTIVE
                 A_pWAKE=double(),      # Percentual de �pocas classificadas como WAKE no per�odo ACTIVE
                 
                 nREST=integer(),       # N�mero de �pocas classificadas como REST
                 R_mAC=double(),        # M�dia dos ACs no per�odo REST
                 R_sdAC=double(),       # Desvio padr�o dos ACs no per�odo REST
                 R_pMOBILE=double(),    # Percentual de �pocas classificadas como MOBILE no per�odo REST
                 R_pWAKE=double(),      # Percentual de �pocas classificadas como WAKE no per�odo REST

                 nSLEEP=integer(),      # N�mero de �pocas classificadas como SLEEP
                 S_mAC=double(),        # M�dia dos ACs no per�odo SLEEP
                 S_sdAC=double(),       # Desvio padr�o dos ACs no per�odo SLEEP
                 S_pMOBILE=double(),    # Percentual de �pocas classificadas como MOBILE no per�odo SLEEP
                 S_pWAKE=double(),      # Percentual de �pocas classificadas como WAKE no per�odo SLEEP
                 S_mDuration=double(),
                 S_sdDuration=double(), 
                 S_mLatency=double(),
                 S_dpLatency=double(),
                 S_mSnooze=double(),
                 S_sdSnooze=double(),
                 S_Efficiency=double(),
                 
                 pACTIVE=double(),
                 pSLEEP=double(),
                 pREST=double(),
                 stringsAsFactors=FALSE) 

write.table(df,file=arqresults,sep=";",dec=",",row.names=FALSE,append=FALSE,quote=FALSE)

for(arquivo in arquivos) {

  conexao <- file(arquivo, encoding="UTF-8-BOM")    
  linhas  <- readLines(conexao, warn=FALSE)
  close(conexao)

  ## BUSCA PELO NOME DO SUJEITO
  linha <- 0
  repeat {
    linha <- linha + 1
    if (sub(";.*","",linhas[linha]) == '"Subject Identity:"') {
      Subject <- sub(".*;","",linhas[linha])
      break
    }
    if (linha == length(linhas)) { break }
  }
  rm(linha,linhas)
  
  cat("Processando arquivo:\n",arquivo,"\n")
  
  ## CARREGA OS DADOS
  dados <- read.table(arquivo, header=TRUE, sep=";", quote="", dec=",", na.strings="NaN", 
                      colClasses=c(rep("character",13)),
                      skip=27, blank.lines.skip=TRUE,stringsAsFactors=TRUE, fileEncoding="UTF-8-BOM",nrows=0)
  
  ## REMOVE VARI�VEIS N�O USADAS
  dados <- dados[c(-1,-5,-6,-8,-9,-13,-14)]
  
  ## RENOMEIA AS VARI�VEIS
  colnames(dados) <- c("Epoch","Day","Seconds","Activity","SleepWake","Mobility","IntervalStatus")
  
  ## REMOVE ASPAS
  dados[] <- lapply(dados,function(aux) {gsub('[\"]','',aux)}) # os [] preservam a estrutura de data frame
  
  tEpochs <- nrow(dados) # n�mero total de �pocas obtido
  
  ## REMOVE �POCAS EXCLUIDAS
  nRemoved  <- sum(dados$IntervalStatus=='EXCLUDED')    # N�mero de �pocas EXCLUDED
  dados     <- dados[dados$IntervalStatus!='EXCLUDED',] # Remove �pocas EXCLUDED
  
  ## RECODIFICA INTERVALOS (ACTIVE=0; REST=1; REST-S=2)
  dados$IntervalStatus[dados$IntervalStatus=="ACTIVE"] <- "0"
  dados$IntervalStatus[dados$IntervalStatus=="REST"]   <- "1"
  dados$IntervalStatus[dados$IntervalStatus=="REST-S"] <- "2"
  
  ## CONVERTE TODAS AS VARI�VEIS PARA FORMATO NUM�RICO
  dados[] <- lapply(dados,as.numeric)
  
  ## CONTA �POCAS COM ACs INV�LIDOS (NaN)
  nRemoved <- nRemoved + sum(is.na(dados$Activity)) # n�mero de �pocas removidas
  
  ## REMOVE �POCAS COM ACs INV�LIDOS (NaN)
  dados <- dados[complete.cases(dados$Activity),]

  nEpochs    <- nrow(dados)
  
  ## LOCALIZA TRANSI��ES DE ESTADOS
  bRestS  <- c() # In�cio do per�odo de descanso antes do sono (Lat�ncia)
  eRestS  <- c() # Fim do per�odo de descanson antes do sono (Lat�ncia)
  bSleep  <- c() # In�cio do per�odo de sono (Sono)
  eSleep  <- c() # Fim do per�odo de sono (Sono)
  bRestW  <- c() # In�cio do per�odo de descan�o depois do sono (Snooze)
  eRestW  <- c() # Fim do per�odo de descan�o depois do sono (Snooze)
  for (i in 2:(nEpochs)) {
    # Transi��o de ACTIVE para REST -> in�cio de REST antes de SLEEP
    if(dados$IntervalStatus[i-1] == 0 & dados$IntervalStatus[i] == 1)
    { bRestS <- c(bRestS,i) }
    # Transi��o de REST para REST-S -> fim de REST e in�cio de SLEEP
    if(dados$IntervalStatus[i-1] == 1 & dados$IntervalStatus[i] == 2)
    { bSleep <- c(bSleep,i)
      eRestS <- c(eRestS,i-1)}
    # Transi��o de REST-S para REST -> fim de SLEEP e in�cio de REST
    if(dados$IntervalStatus[i-1] == 2 & dados$IntervalStatus[i] == 1)
    { eSleep <- c(eSleep,i-1)
      bRestW <- c(bRestW,i)}
    # Transi��o de REST para ACTIVE -> fim de REST
    if(dados$IntervalStatus[i-1] == 1 & dados$IntervalStatus[i] == 0)
    { eRestW <- c(eRestW,i-1) }
    # Transi��o de ACTIVE para REST-S -> in�cio de SLEEP sem REST
    if(dados$IntervalStatus[i-1] == 0 & dados$IntervalStatus[i] == 2)
    { bSleep <- c(bSleep,i) }
    # Transi��o de REST-S para ACTIVE -> fim de SLEEP sem REST
    if(dados$IntervalStatus[i-1] == 2 & dados$IntervalStatus[i] == 0)
    { eSleep <- c(eSleep,i-1) }
  }
  
  ## ESTAT�STICAS DA COLETA TODA
  mAC       <- mean(dados$Activity,na.rm=TRUE)
  sdAC      <- sd(dados$Activity,na.rm=TRUE)
  pMOBILE   <- nrow(dados[dados$Mobility==1,]) / nEpochs
  pWAKE     <- nrow(dados[dados$SleepWake==1,]) / nEpochs
  
  ## ESTAT�STICAS DOS INTERVALOS CLASSIFICADOS COMO ATIVO (=0)
  nACTIVE   <- nrow(dados[dados$IntervalStatus==0,])
  A_mAC     <- mean(dados[dados$IntervalStatus==0,]$Activity,na.rm=TRUE)
  A_sdAC    <- sd(dados[dados$IntervalStatus==0,]$Activity,na.rm=TRUE)
  A_pMOBILE <- nrow(dados[dados$IntervalStatus==0 & dados$Mobility==1,]) / nACTIVE
  A_pWAKE   <- nrow(dados[dados$IntervalStatus==0 & dados$SleepWake==1,]) / nACTIVE
  
  ## ESTAT�STICAS DOS INTERVALOS CLASSIFICADOS COMO REST (=1)
  nREST     <- nrow(dados[dados$IntervalStatus==1,])
  R_mAC     <- mean(dados[dados$IntervalStatus==1,]$Activity,na.rm=TRUE)
  R_sdAC    <- sd(dados[dados$IntervalStatus==1,]$Activity,na.rm=TRUE)
  R_pMOBILE <- nrow(dados[dados$IntervalStatus==1 & dados$Mobility==1,]) / nREST
  R_pWAKE   <- nrow(dados[dados$IntervalStatus==1 & dados$SleepWake==1,]) / nREST
  
  ## ESTAT�STICAS DOS INTERVALOS CLASSIFICADOS COMO REST-S (=2)
  nSLEEP       <- nrow(dados[dados$IntervalStatus==2,])
  S_mAC        <- mean(dados[dados$IntervalStatus==2,]$Activity,na.rm=TRUE)
  S_sdAC       <- sd(dados[dados$IntervalStatus==2,]$Activity,na.rm=TRUE)
  S_pMOBILE    <- nrow(dados[dados$IntervalStatus==2 & dados$Mobility==1,]) / nSLEEP
  S_pWAKE      <- nrow(dados[dados$IntervalStatus==2 & dados$SleepWake==1,]) / nSLEEP
  S_Lengths    <- eSleep - bSleep   # Dura��o dos per�odos de sono (em �pocas)
  S_mDuration  <- mean(S_Lengths) # Dura��o m�dia dos per�odos de sono (em �pocas)
  S_sdDuration <- sd(S_Lengths)   # Desvio padr�o da m�dia dos per�odos de sono (em �pocas)
  S_Latency    <- eRestS - bRestS   # Dura��o das lat�ncias (em �pocas)
  S_mLatency   <- mean(S_Latency) # Dura��o m�dia das lat�ncias (em �pocas)
  S_sdLatency  <- sd(S_Latency)  # Desvio padr�o da m�dia das lat�ncias (em �pocas)
  S_Snooze     <- eRestW - bRestW     # Dura��o dos snooze (em �pocas)
  S_mSnooze    <- mean(S_Snooze)     # Dura��o m�dio dos snooze (em �pocas)
  S_sdSnooze   <- sd(S_Snooze)      # Desvio padr�o m�dio dos snooze (em �pocas)
  S_Efficiency <- nSLEEP  / (sum(eRestS-bRestS) + nSLEEP)
  
  pACTIVE <- nACTIVE / nEpochs
  pSLEEP  <- nSLEEP  / nEpochs
  pREST   <- nREST   / nEpochs
  
  df = rbind(df,data.frame(Subject,tEpochs,nRemoved,nEpochs,
                           mAC,sdAC,pMOBILE,pWAKE,
                           nACTIVE,A_mAC,A_sdAC,A_pMOBILE,A_pWAKE,
                           nREST,R_mAC,R_sdAC,R_pMOBILE,R_pWAKE,
                           nSLEEP,S_mAC,S_sdAC,S_pMOBILE,S_pWAKE,
                           S_mDuration,S_sdDuration,S_mLatency,S_sdLatency,S_mSnooze,S_sdSnooze,S_Efficiency,
                           pACTIVE,pSLEEP,pREST,
                           stringsAsFactors=FALSE))
}

write.table(df,file=arqresults,sep=";",dec=",",row.names=FALSE,col.names=FALSE,append=TRUE,quote=FALSE)
rm(list=ls())  # Remove todos os objetos
cat("Fim!")