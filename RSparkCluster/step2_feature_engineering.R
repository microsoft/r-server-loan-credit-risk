##########################################################################################################################################
## This R script will do the following :
## 1. Create the label isBad based on the status of the loan. 
## 2. Split the data set into a Training and a Testing set.
## 3. Bucketize all the numeric variables, based on Conditional Inference Trees, using the smbinning package on the Training set. 
## 4. Specify correctly the variable types and drop the variables used to compute the new features. 

## Input : Cleaned data set MergedCleaned.
## Output: Data set with new features MergedFeaturesFactors. 

##########################################################################################################################################

## Function for feature engineering:

# LocalWorkDir: the working directory on the edge node.
# HDFSWorkDir: the working directory on HDFS.
# splitting_ratio: the proportion (in ]0,1]) of observations that will end in the training set. 
# Stage: "Dev" for development, "Prod" for batch scoring, or "Web" for scoring remotely with web service.


feature_engineer <- function(LocalWorkDir,
                             HDFSWorkDir,
                             splitting_ratio = 0.7,
                             Stage)
{ 
  
  # Define the intermediate directory holding the input data. 
  HDFSIntermediateDir <- file.path(HDFSWorkDir,"temp")
  
  # Define the directory where bins and variable information will be saved in the Development stage or loaded from in Production.
  LocalModelsDir <- file.path(LocalWorkDir, "model")
  
  # Point to the input data.
  MergedCleaned_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedCleaned"), fileSystem = RxHdfsFileSystem())
  
  #############################################################################################################################################
  ## For the development stage, the block below will:
  ## 1. Create the label, isBad, based on the loanStatus variable. 
  ## 2. Create a variable, hashCode, which correspond to the mapping of loanId to integers using murmur3.32 hash function.
  ############################################################################################################################################
  if(Stage == "Dev"){
    print("Creating the label isBad based on loanStatus...")
    
    # Point to the Output SQL table:
    MergedLabeled_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedLabeled"), fileSystem = RxHdfsFileSystem())
    
    # Create the target variable, isBad, based on loanStatus.
    # We also map the loanId to integers with the murmur3.32 hash function.
    rxDataStep(inData = MergedCleaned_xdf ,
               outFile = MergedLabeled_xdf, 
               overwrite = TRUE, 
               transforms = list(
                 isBad = ifelse(loanStatus %in% c("Current"), "0", "1"),
                 hashCode = sapply(as.character(loanId), murmur3.32)
               ), 
               transformPackages = "hashFunction"
    )
  }
  
  if(Stage == "Prod" | Stage == "Web" ){
    # Since there is no loanStatus variable in data to score, we create a fake isBad variable not used later.
    
    # Point to the Output SQL table:
    MergedLabeled_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedLabeled"), fileSystem = RxHdfsFileSystem())
    
    # Create the fake target variable isBad. 
    rxDataStep(inData = MergedCleaned_xdf ,
               outFile = MergedLabeled_xdf, 
               overwrite = TRUE, 
               transforms = list(
                 isBad = sample(c("0", "1"), size = .rxNumRows, replace = TRUE)) 
    )
  }
  
  #############################################################################################################################################
  ## Development: The block below will create Training set to compute bins. 
  ############################################################################################################################################
  if(Stage == "Dev"){
    
    print("Creating a training set to be used to compute bins...")
    
    # Create the training set.
    # It will be used to compute bins for numeric variables with smbining. 
    Train_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "Train"), fileSystem = RxHdfsFileSystem())
    
    rxDataStep(inData = MergedLabeled_xdf,
               outFile = Train_xdf,
               overwrite = TRUE,
               rowSelection = (hashCode %% 100 < 100*splitting_ratio), 
               transformObjects = list(splitting_ratio = splitting_ratio))
  }
  
  #############################################################################################################################################
  ## The block below will compute (load for Production or Web-Scoring) the bins for various numeric variables.
  ## smbinning is applied in-memory to the training set loaded as a data frame. 
  ############################################################################################################################################
  
  # Development: We compute the global quantiles for various numeric variables.
  if(Stage == "Dev"){
    print("Computing the bins to be used to create buckets...")
    
    # Using the smbinning has some limitations, such as: 
    # - The variable should have more than 10 unique values. 
    # - If no significant splits are found, it does not output bins. 
    # For this reason, we manually specify default bins based on an analysis of the variables distributions or smbinning on a larger data set. 
    # We then overwrite them with smbinning when it output bins. 
    
    bins <- list()
    
    # Default cutoffs for bins:
    ## EXAMPLE: If the cutoffs are (c1, c2, c3),
    ## Bin 1 = ]- inf, c1], Bin 2 = ]c1, c2], Bin 3 = ]c2, c3], Bin 4 = ]c3, + inf] 
    ## c1 and c3 are NOT the minimum and maximum found in the training set. 
    bins$loanAmount <- c(13343, 15365, 16648, 17769, 19230, 20545, 22101, 22886, 24127, 24998, 27416)
    bins$interestRate <- c(6.99, 8.78, 10.34, 11.13, 11.91, 12.72, 13.75, 14.59, 15.85, 18.01)
    bins$monthlyPayment <- c(318, 360, 393, 440, 485, 520, 554, 595, 635, 681, 741, 855)
    bins$annualIncome <- c(50022, 51632, 52261, 53075, 53854, 54430, 55055, 55499, 56171, 56913, 57735, 58626, 59715)
    bins$dtiRatio <- c(9.08, 11.95, 13.77, 14.54, 15.43, 16.48, 17.54, 18.27, 19.66, 20.46, 21.29, 22.87, 25.03)
    bins$lengthCreditHistory <- c(6, 7, 9)
    bins$numTotalCreditLines <- c(1, 2)
    bins$numOpenCreditLines <- c(3, 5)
    bins$numOpenCreditLines1Year <- c(3, 4, 5, 6, 7, 8)
    bins$revolvingBalance <- c(10722, 11630, 12298, 12916, 13317, 13797, 14256, 14633, 15174, 15680, 16394, 16796, 17257, 18180)
    bins$revolvingUtilizationRate <- c(43.89, 49.36, 53.72, 57.61, 61.41, 64.45, 69.81, 74.05, 76.98, 82.14, 90.54)
    bins$numDerogatoryRec <- c(0, 1)
    bins$numDelinquency2Years <- c(0, 10)
    bins$numChargeoff1year <- c(0, 8)
    bins$numInquiries6Mon <- c(0, 1, 2)
    
    
    # Function to compute smbinning on every variable. 
    ## For large data sets, we take a random subset to speed up computations with smbinning.
    compute_bins <- function(name, data){
      
      # Import the training set to be able to apply smbinning and set the type of the label to numeric. 
      Train_df <- rxImport(data, varsToKeep = c("isBad", name))
      ## We take a subset of the training set to speed up computations for very large data sets.
      Train_df <- Train_df[sample(seq(1, nrow(Train_df)), replace = FALSE, size = min(300000, nrow(Train_df))), ] 
      Train_df$isBad <- as.numeric(as.character(Train_df$isBad))
      
      # Compute the cutoffs with smbinning. 
      library(smbinning)
      output <- smbinning(Train_df, y = "isBad", x = name, p = 0.05)
      if (class(output) == "list"){ # case where the binning was performed and returned bins.
        cuts <- output$cuts  
        return (cuts)
      }
    }
    
    # We apply it in parallel on the variables accross the nodes of the cluster with the rxExec function. 
    rxOptions(numCoresToUse = -1) # use of the maximum number of cores.
    bins_smb <- rxExec(compute_bins, name = rxElemArg(names(bins)), data = Train_xdf)
    names(bins_smb) <- names(bins)
    
    # Fill b with bins obtained in bins_smb with smbinning. 
    ## We replace the default values in bins if and only if smbinning returned a non NULL result. 
    for(name in names(bins)){
      if (!is.null(bins_smb[[name]])){ 
        bins[[name]] <- bins_smb[[name]]
      }
    }
    
    ## Saving for Production use. 
    saveRDS(bins, file.path(LocalModelsDir, "bins.rds"))
  } 
  
  # Production: We load the bins computed during Development. 
  if(Stage == "Prod"){
    print("Loading the bins to be used to create buckets...")
    bins <- readRDS(file.path(LocalModelsDir, "bins.rds")) 
  }
  
  # Web Scoring: we directly read the bins computed in the Development stage. 
  # They are included in the list model_objects, defined in "deployment.R". It can be used when calling the published web service.
  if(Stage == "Web"){
    print("Loading the bins to be used to create buckets...")
    bins <- model_objects$bins
  }
  
  #############################################################################################################################################
  ## The block below will bucketize the numeric variables based on the computed or defined bins.
  ############################################################################################################################################
  print("Bucketizing numeric variables...")
  
  # Function to bucketize numeric variables. It will be wrapped into rxDataStep. 
  bucketize <- function(data) { 
    for(name in  names(b)) { 
      name2 <- paste(name, "Bucket", sep = "") 
      data[[name2]] <- as.character(as.numeric(cut(data[[name]], c(-Inf, b[[name]], Inf)))) 
    }
    return(data) 
  }
  
  # Perform feature engineering on the cleaned data set.
  
  ## Create an XDF pointer for the output.
  MergedFeatures_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedFeatures"), fileSystem = RxHdfsFileSystem())
  
  ## Apply the function Bucketize to MergedLabeled_xdf. 
  rxDataStep(inData = MergedLabeled_xdf,
             outFile = MergedFeatures_xdf, 
             overwrite = TRUE, 
             transformFunc = bucketize,
             transformObjects =  list(
               b = bins))
  
  #############################################################################################################################################
  ## The block below will:
  ## Development: set the type of the newly created variables to factor and save the variable information for Production/Web Scoring use. 
  ## Production/ Web Scoring: factor the variables and specify their levels accordingly to the Development data. 
  ############################################################################################################################################
  
  # Create an XDF pointer to the output data. 
  MergedFeaturesFactors_xdf <- RxXdfData(file.path(HDFSIntermediateDir, "MergedFeaturesFactors"), fileSystem = RxHdfsFileSystem())
  
  # Development stage. 
  if(Stage == "Dev"){
    
    print("Transforming newly created variables to factors...")
    
    # Add the newly created variables to a column_factor_info list to be used in rxFactors. 
    new_names <- paste(names(bins), "Bucket", sep = "")
    new_levels <- unlist(lapply(bins, function(x) length(x) + 1))
    column_factor_info = mapply(function(i, new_levels){list(levels = as.character(seq(1, new_levels)) )}, 1:length(new_levels), new_levels,SIMPLIFY = FALSE)
    names(column_factor_info) <- new_names 
    
    # Convert the new features from character to factors. 
    ## We drop the numeric variables and loanStatus, used to compute the new features. 
    rxFactors(inData = MergedFeatures_xdf , outFile = MergedFeaturesFactors_xdf,  factorInfo = column_factor_info, varsToDrop = c("loanStatus", smb_buckets_names))
    
    print("Saving the variable information for Production and Web Scoring use...")
    
    # Add to column_factor_info the levels of the other factor variables, for use in Production and Web Scoring. 
    
    ## Get the names of the other factor variables.
    colnames <- names(MergedFeaturesFactors_xdf)
    colnames_other <- colnames[!(colnames %in% c("isBad", new_names))]
    
    ## Add them to the column_factor_info list. 
    var_info <- rxGetVarInfo(MergedFeaturesFactors_xdf)
    for(name in colnames_other){
      if(var_info[[name]]$varType == "factor"){
        column_factor_info[[name]]$newLevels <- var_info[[name]]$levels
      }
    }
    
    # Remove the date factor info (its levels will rarely match those of a Production data set)
    column_factor_info$date <- NULL
    
    ## Save column_factor_info for Production or Web Scoring. 
    saveRDS(column_factor_info, file.path(LocalModelsDir, "column_factor_info.rds"))
  }
  # Production stage.   
  if(Stage == "Prod"){
    
    # Load the variable information from the Development stage. 
    column_factor_info <- readRDS(file = file.path(LocalModelsDir, "column_factor_info.rds"))
    
    # Convert the new features to factor and specify the levels of the other factors in the order of the Development data. 
    rxFactors(inData = MergedFeatures_xdf , outFile = MergedFeaturesFactors_xdf,  factorInfo = column_factor_info, varsToDrop = c(smb_buckets_names))
  }
  
  # Web Scoring stage.   
  if(Stage == "Web"){
    
    ## For the Web Scoring, we directly read the factorInfo computed in the Development stage. 
    ## It is included in the list model_objects, defined in "deployment.R". It can be used when calling the published web service.
    column_factor_info <- model_objects$column_factor_info
    
    # Convert the new features to factor and specify the levels of the other factors in the order of the Development data. 
    rxFactors(inData = MergedFeatures_xdf , outFile = MergedFeaturesFactors_xdf,  factorInfo = column_factor_info, varsToDrop = c(smb_buckets_names))
  }
  
  print("Step 2 Completed.")
} # end of step 2 function. 





