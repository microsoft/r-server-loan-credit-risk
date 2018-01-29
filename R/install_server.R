# To be executed on the computer where SQL Server is installed
# This will install the packages needed for this solution to SQL Server R Services
# This has already been run for you if you have deployed the solution from Cortana Intelligence Gallery

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

print("Done installing packages")
