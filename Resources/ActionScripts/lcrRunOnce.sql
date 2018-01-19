EXEC merging 'Loan', 'Borrower', 'Merged'
EXEC compute_stats 'Merged'
EXEC fill_NA_mode_mean 'Merged', 'Merged_Cleaned'
EXEC splitting 'Merged_Cleaned'
"EXEC compute_bins 'SELECT Merged_Cleaned.*, isBad = CASE WHEN loanStatus IN (''Current'') THEN ''0'' ELSE ''1'' END
                                 FROM  Merged_Cleaned JOIN Hash_Id ON Merged_Cleaned.loanId = Hash_Id.loanId 
                                 WHERE hashCode <= 70'
EXEC feature_engineering 'Merged_Cleaned', 'Merged_Features'
EXEC get_column_info 'Merged_Features'
EXEC train_model 'Merged_Features'
EXEC score 'SELECT * FROM Merged_Features WHERE loanId NOT IN (SELECT loanId from Hash_Id WHERE hashCode <= 70)', 'Predictions_Logistic'
EXEC evaluate 'Predictions_Logistic'
EXEC compute_operational_metrics 'Predictions_Logistic'
EXEC apply_score_transformation 'Predictions_Logistic', 'Scores'

*** Production pipeline
EXEC merging 'Loan_Prod', 'Borrower_Prod', 'Merged_Prod'
EXEC fill_NA_mode_mean 'Merged_Prod', 'Merged_Cleaned_Prod'
EXEC feature_engineering 'Merged_Cleaned_Prod', 'Merged_Features_Prod'
EXEC score 'SELECT * FROM Merged_Features_Prod', 'Predictions_Logistic_Prod' 
exec apply_score_transformation 'Predictions_Logistic_Prod', 'Scores_Prod'
ALTER TABLE Scores_Prod DROP COLUMN isBad
