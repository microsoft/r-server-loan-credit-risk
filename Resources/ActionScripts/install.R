print("Start installing SQL Version packages")

install.packages("smbinning", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("sqldf", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("gsubfn", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("proto", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("RSQLite", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("DBI", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("partykit", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("Formula", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("ROCR", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")
install.packages("chron", lib="C:/Program Files/Microsoft SQL Server/MSSQL14.MSSQLSERVER/R_SERVICES/library")

print("Done installing SQL Version packages")

print("Start installing Local Version packages")

install.packages("smbinning", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("sqldf", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("gsubfn", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("proto", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("RSQLite", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("DBI", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("partykit", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("Formula", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("ROCR", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")
install.packages("chron", lib="C:/Program Files/Microsoft/ML Server/R_SERVER/library")


print("Done installing Local packages")

