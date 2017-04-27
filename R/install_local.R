# To be executed on the computer where you will run R Server
# This will install the packages needed for this solution
# This has already been run on your VM if you have deployed the solution from Cortana Intelligence Gallery.

install.packages("smbinning", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("sqldf", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("gsubfn", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("proto", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("RSQLite", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("DBI", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("partykit", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("Formula", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("ROCR", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")
install.packages("chron", lib="C:/Program Files/Microsoft/R Server/R_SERVER/library")

print("Done installing packages")
