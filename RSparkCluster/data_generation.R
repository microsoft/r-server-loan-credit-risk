##########################################################################################################################################
## Declare the number of unique loans and members.
##########################################################################################################################################

# Let's assume each member applied to only one loan.  
no_of_unique_id <- 1000000

##########################################################################################################################################
## Generate loan_id and member_id. 
##########################################################################################################################################

loanId <- sample(x = seq(no_of_unique_id, (no_of_unique_id + 9*no_of_unique_id )), size = no_of_unique_id , replace = FALSE, prob = NULL)
memberId <- sample(x = seq(2*no_of_unique_id, (2*no_of_unique_id + 9*no_of_unique_id )), size = no_of_unique_id , replace = FALSE, prob = NULL)

LB <- data.frame(loanId = loanId, memberId = memberId)

##########################################################################################################################################
## Generate is_bad variable randomly with prior probability 0.9 for is_bad = 0. 
##########################################################################################################################################

LB$isBad <- sample(c("0","1"), no_of_unique_id, replace = T, prob = c(0.9, 0.1))


##########################################################################################################################################
## Generate some variables independently of the label. 
##########################################################################################################################################

# Term and application type.
LB$term <- sample(c("36 months","48 months","60 months"), no_of_unique_id, replace = T, prob = c(0.33, 0.33, 0.34))
LB$isJointApplication <- sample(c("0", "1"), no_of_unique_id, replace = T, prob = c(0.95, 0.05))

# Total accounts and open accounts: open should be <= total. 
LB$numTotalCreditLines <- round(rnorm(no_of_unique_id , mean = 15, sd = 4), digits = 0)
LB$numTotalCreditLines <- ifelse(LB$numTotalCreditLines < 1, 1, 
                                 ifelse(LB$numTotalCreditLines > 35, 35, LB$numTotalCreditLines))

LB$numOpenCreditLines <- pmax(1, LB$numTotalCreditLines - round(runif(no_of_unique_id, min = 0, max =  LB$numTotalCreditLines/2)))

# Address (without Hawaii HI, Alaska AK and Puerto Rico PR).
LB$residentialState <- sample(c("AL",	"AZ",	"AR",	"CA",	"CO",	"CT",	"DE",	"DC",	"FL",	"GA",	"ID",	"IL", "IN",	"IA",		
                                "KS",	"KY",	"LA",	"ME",	"MD",	"MA",	"MI",	"MN",	"MS",	"MO",	"MT",	"NE",	"NV",	"NH",	"NJ",
                                "NM",	"NY",	"NC",	"ND",	"OH",	"OK",	"OR",	"PA",	"RI",	"SC",	"SD",	"TN",	"TX",	"UT",	"VT",
                                "VA",	"WA",	"WV",	"WI",	"WY"),
                              no_of_unique_id, replace = T, 
                              prob = c(rep(0.4/49, 3), 3.4/49, rep(0.4/49, 3), 2.5/49, 3.2/49, 0.4/49, rep(0.955/49, 20),
                                       3/49, rep(0.5/49, 4), rep(1/49, 6), 2/49, rep(0.5/49, 3), 2/49, rep(0.5/49, 3))
)
## We will not provide a zip_code variable.

# Issue Date. 
LB$date <- format(sample(seq(ISOdate(2014, 5, 13), ISOdate(2016, 6, 30), by = "day"), no_of_unique_id, replace = T),"%Y-%m-%d")

# Variables left to generate based on the label: 
continuous <- c("loanAmount", "interestRate", "annualIncome", "dtiRatio", "revolvingBalance", "revolvingUtilizationRate")
integer <- c("numDelinquency2Years", "numDerogatoryRec", "numChargeoff1year", "numInquiries6Mon", "lengthCreditHistory", 
             "numOpenCreditLines1Year")
character <- c("grade", "purpose", "yearsEmployment", "homeOwnership", "incomeVerified")   

## monthlyPayment and loanStatus will be created at the end:
### monthlyPayment: using a formula based on interest rate, loan amount and term. 
### loanStatus: based on isBad and then we remove is_bad. 

# Split in 2 to sample conditionally on isBad.
LB0 <- LB[LB$isBad == "0", ]
n0 <- nrow(LB0)
LB1 <- LB[LB$isBad == "1", ]
n1 <- nrow(LB1)

##########################################################################################################################################
## CHARACTER: Conditional probabilities for variables based on is_bad. 
##########################################################################################################################################

character <- c("grade", "purpose", "yearsEmployment", "homeOwnership", "incomeVerified")  

# Probabilities conditional on labels 0 and 1.
grade_list <- c("A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2", "C3", "D1", "D2", "D3", "E1", "E2", "E3")
grade_p0 <- c(1.8, 1.7, 1.7, 1.4, 1.3, 1.3, 1.1, 1, 0.8,  0.6, 0.6, 0.5, 0.4, 0.4, 0.4)/15
grade_p1 <- rev(grade_p0)  

purpose_list <- c("debtconsolidation", "healthcare", "education", "business", "auto", "homeimprovement", "other")
purpose_p0 <- c(0.82, 0.01, 0.01, 0.03, 0.01, 0.08, 0.04)
purpose_p1 <- c(0.78, 0.03, 0.01, 0.04, 0.01, 0.09, 0.04)

yearsEmployment_list <- c("< 1 year", "1 year", "2-5 years", "6-9 years", "10+ years")
yearsEmployment_p0 <- c(0.19, 0.19, 0.19, 0.20, 0.23)
yearsEmployment_p1 <- rev(yearsEmployment_p0)

homeOwnership_list <- c("own", "rent", "mortgage")
homeOwnership_p0 <- c(0.31, 0.33, 0.36)
homeOwnership_p1 <- c(0.30, 0.32, 0.38)

incomeVerified_list <- c("0", "1")
incomeVerified_p0 <- c(0.32, 0.68)
incomeVerified_p1 <- c(0.23, 0.67)

# Generate the variables. 
for (name in character){
  LB0[,name] <- sample(get(paste(name, "_list", sep = "")), n0, replace = T, prob =  get(paste(name, "_p0", sep = "")))
  LB1[,name] <- sample(get(paste(name, "_list", sep = "")), n1, replace = T, prob =  get(paste(name, "_p1", sep = "")))
}


##########################################################################################################################################
## INTEGER: Conditional probabilities for variables based on is_bad. 
##########################################################################################################################################

integer <- c("numDelinquency2Years", "numDerogatoryRec", "numChargeoff1year", "numInquiries6Mon", "lengthCreditHistory", 
             "numOpenCreditLines1Year")

# Some variables are directly related: 
## Assuming that a chargeoff is a delinquency, we should have "numChargeoff1year" <= "numDelinquency2Years"
## "numOpenCreditLines1Year" should be <= "numOpenCreditLines".

integer0 <- c("numDelinquency2Years", "numDerogatoryRec", "numInquiries6Mon", "lengthCreditHistory")

numDelinquency2Years_list <- seq(0, 20) 
numDelinquency2Years_p0 <- c(0.75, 0.08, 0.02, 0.02, rep(0.01, 7), rep(0.006, 10))   
numDelinquency2Years_p1 <- c(0.71, 0.09, 0.03, 0.026, rep(0.012, 7), rep(0.006, 10))

numDerogatoryRec_list <- seq(0, 15) 
numDerogatoryRec_p0 <- c(0.82, 0.07, 0.018, rep(0.009, 8), rep(0.004, 5))   
numDerogatoryRec_p1 <- c(0.79, 0.09, 0.02, rep(0.01, 8), rep(0.004, 5)) 

numInquiries6Mon_list <- seq(0, 19) 
numInquiries6Mon_p0 <- c(0.55, 0.25, 0.09, 0.031, rep(0.005, 15), 0.004)   
numInquiries6Mon_p1 <- c(0.45, 0.30, 0.12, 0.037, rep(0.006, 15), 0.003)

lengthCreditHistory_list <- seq(1, 40) 
lengthCreditHistory_p0 <- c(0.08, 0.08, 0.08, 0.08, 0.09, 0.09, 0.05, 0.05, 0.05, 0.05, rep(0.01, 30))   
lengthCreditHistory_p1 <- c(0.09, 0.09, 0.10, 0.09, 0.10, 0.10, 0.06, 0.05, 0.04, 0.04, rep(0.008, 30))  

## Generate the first set of variables. 
for (name in integer0){
  LB0[,name] <- sample(get(paste(name, "_list", sep = "")), n0, replace = T, prob =  get(paste(name, "_p0", sep = "")))
  LB1[,name] <- sample(get(paste(name, "_list", sep = "")), n1, replace = T, prob =  get(paste(name, "_p1", sep = "")))
}

## Generate the dependent variables. 
LB0$numChargeoff1year <-  pmax(0, LB0$numDelinquency2Years - round(runif(n0, min = 0, max =  LB0$numDelinquency2Years/2)))
LB1$numChargeoff1year <-  pmax(0, LB1$numDelinquency2Years - round(runif(n1, min = 0, max =  LB1$numDelinquency2Years/2)))

LB0$numOpenCreditLines1Year <-  pmax(1, LB0$numOpenCreditLines - round(runif(n0, min = 0, max =  LB0$numOpenCreditLines/1.5)))
LB1$numOpenCreditLines1Year <-  pmax(1, LB1$numOpenCreditLines - round(runif(n1, min = 0, max =  LB1$numOpenCreditLines/2)))

##########################################################################################################################################
## CONTINUOUS: Distributions with means dependent on the label isBad. 
##########################################################################################################################################

continuous <- c("loanAmount", "interestRate", "annualIncome", "dtiRatio", "revolvingBalance", "revolvingUtilizationRate")

# loanAmount. We first generate it as a normal dist based on is_bad, then we increase it for some States. 
LB0$loanAmount <- round(rnorm(n0, mean = 20000, sd = 4500), digits = 0)
LB1$loanAmount <- round(rnorm(n1, mean = 22000, sd = 4500), digits = 0)
LB0$loanAmount <- ifelse(LB0$loanAmount <= 1000, 1000, LB0$loanAmount)
LB1$loanAmount <- ifelse(LB1$loanAmount <= 1000, 1000, LB1$loanAmount)

LB0$loanAmount <- ifelse(LB0$residentialState == "CA", LB0$loanAmount + round(runif(n0, min = 0, max =  8000)), 
                         ifelse (LB0$residentialState == "NY", LB0$loanAmount + round(runif(n0, min = 0, max = 5000)),
                                 ifelse(LB0$residentialState == "FL", LB0$loanAmount + round(runif(n0, min = 0, max =  2000)),
                                        ifelse(LB0$residentialState == "TX", LB0$loanAmount + round(runif(n0, min = 0, max =  1000)),
                                               LB0$loanAmount)))) 


LB1$loanAmount <- ifelse(LB1$residentialState == "CA", LB1$loanAmount + round(runif(n1, min = 0, max =  10000)), 
                         ifelse (LB1$residentialState == "NY", LB1$loanAmount + round(runif(n1, min = 0, max =  6000)),
                                 ifelse(LB1$residentialState == "FL", LB1$loanAmount + round(runif(n1, min = 0, max =  3000)),
                                        ifelse(LB1$residentialState == "TX", LB1$loanAmount + round(runif(n1, min = 0, max =  2000)),
                                               LB1$loanAmount)))) 


# interestRate. 
LB0$interestRate <- round(4 + 20*rbeta(n0, 2, 4), digits = 2)
LB1$interestRate <- round(4 + 30*rbeta(n1, 2, 4), digits = 2)

# annualIncome. 
LB0$annualIncome <- round(rnorm(n0, mean = 55000, sd = 3000), digits = 0)
LB1$annualIncome <- round(rnorm(n1, mean = 52000, sd = 3500), digits = 0)
LB0$annualIncome <- ifelse(LB0$annualIncome < 13000, 13000, LB0$annualIncome)
LB1$annualIncome <- ifelse(LB1$annualIncome < 13000, 13000, LB1$annualIncome)

## dtiRatio cannot be computed directly from data, so we can generate it only based on is_bad. 
LB0$dtiRatio <- round(rnorm(n0, mean = 17, sd = 5), digits = 2)
LB1$dtiRatio <- round(rnorm(n1, mean = 20, sd = 5), digits = 2)
LB0$dtiRatio <- ifelse(LB0$dtiRatio < 0, 0, LB0$dtiRatio)
LB1$dtiRatio <- ifelse(LB1$dtiRatio < 0, 0, LB1$dtiRatio)


## revolvingBalance and revolvingUtilizationRate are correlated (0.21 on real data): the higher the balance and the higher the utilization rate.   

LB0$revolvingBalance <- round(rnorm(n0, mean = 15000, sd = 2500), digits = 0)
LB1$revolvingBalance <- round(rnorm(n1, mean = 13500, sd = 2250), digits = 0)
LB0$revolvingBalance <- ifelse(LB0$revolvingBalance < 0, 0, LB0$revolvingBalance)
LB1$revolvingBalance <- ifelse(LB1$revolvingBalance < 0, 0, LB1$revolvingBalance)

LB0$revolvingUtilizationRate <- ifelse(LB0$revolvingBalance == 0, 0,
                                       ifelse(LB0$revolvingBalance <= 10000, round(rnorm(n0, mean = 45, sd = 5), digits = 2),
                                              ifelse(LB0$revolvingBalance <= 20000, round(rnorm(n0, mean = 65, sd = 15), digits = 2),
                                                     round(rnorm(n0, mean = 75, sd = 25), digits = 2))))

LB1$revolvingUtilizationRate <- ifelse(LB1$revolvingBalance == 0, 0,
                                       ifelse(LB1$revolvingBalance <= 8000, round(rnorm(n1, mean = 48, sd = 5), digits = 2),
                                              ifelse(LB1$revolvingBalance <= 18000, round(rnorm(n1, mean = 69, sd = 15), digits = 2),
                                                     round(rnorm(n1, mean = 77, sd = 25), digits = 2))))


LB0$revolvingUtilizationRate <- ifelse(LB0$revolvingUtilizationRate < 0, 0,
                                       ifelse(LB0$revolvingUtilizationRate > 100, 100, 
                                              LB0$revolvingUtilizationRate))

LB1$revolvingUtilizationRate <- ifelse(LB1$revolvingUtilizationRate < 0, 0,
                                       ifelse(LB1$revolvingUtilizationRate > 100, 100, 
                                              LB1$revolvingUtilizationRate))

##########################################################################################################################################
## Binding LB0 and LB1 + Additional Perturbations and Modifications.  
##########################################################################################################################################

# Bind and then shuffle rows.
LB <- rbind(LB0, LB1)
LB <- LB[sample(nrow(LB), nrow(LB), replace = F), ] 

# Generate loanStatus based on isBad. 
LB$loanStatus <- ifelse(LB$isBad == "0", "Current", "Default")

# Generate monthlyPayment based on interest rate, loan amount and term. 
LB$term2 <- as.character(LB$term)
LB$term2 <- as.numeric(gsub("months", "", LB$term2))
LB$interestRate2 <- LB$interestRate/(12*100)

LB$monthlyPayment <- round(LB$loanAmount*(LB$interestRate2)/(1 - (1 + LB$interestRate2)**(-LB$term2)), digits = 0)

# Add missing values. 
LB$loanAmount <- ifelse(sample(c(1, 2), no_of_unique_id, replace = T, prob = c(0.99, 0.01)) == 1, LB$loanAmount, "")
LB$term <- ifelse(sample(c(1, 2), no_of_unique_id, replace = T, prob = c(0.99, 0.01)) == 1, LB$term, "")
LB$isJointApplication <- ifelse(sample(c(1, 2), no_of_unique_id, replace = T, prob = c(0.99, 0.01)) == 1, LB$isJointApplication, "")
LB$numOpenCreditLines <- ifelse(sample(c(1, 2), no_of_unique_id, replace = T, prob = c(0.99, 0.01)) == 1, LB$numOpenCreditLines, "")


##########################################################################################################################################
## Separate in Loan and Borrower and write to disk on the edge node. 
##########################################################################################################################################

colnames_loan <- c("loanId", "memberId", "date", "purpose", "isJointApplication", 
                   "loanAmount", "term", "interestRate", "monthlyPayment", "grade", "loanStatus" )

colnames_borrower <- c("memberId", "residentialState", "yearsEmployment", "homeOwnership", "annualIncome", "incomeVerified",
                       "dtiRatio", "lengthCreditHistory", "numTotalCreditLines", "numOpenCreditLines", "numOpenCreditLines1Year",
                       "revolvingBalance", "revolvingUtilizationRate", "numDerogatoryRec", "numDelinquency2Years", 
                       "numChargeoff1year", "numInquiries6Mon")   

Loan <- LB[, colnames_loan]
Borrower <- LB[, colnames_borrower]

write.csv(Loan, file = "Loan.csv", row.names = FALSE , quote = FALSE, na = "")
write.csv(Borrower, file = "Borrower.csv", row.names = FALSE , quote = FALSE, na = "")

##########################################################################################################################################
## Copy the data to HDFS. 
##########################################################################################################################################

source = paste0(getwd(), "/*.csv");
DataDir = "/Loans/Data"

# Copy the data from the edge node to HDFS. 
rxHadoopCopyFromLocal(source, DataDir)

# Remove local files.
file.remove("Loan.csv")
file.remove("Borrower.csv")

# Clean up the environment.  
rm(list = ls())