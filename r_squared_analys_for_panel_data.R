# Advanced R-squared Analysis for panel data with R6 Classes
# Author: Ali Fadakar
# Repository: https://github.com/kamran-1987/r_squared_analysis_for_panel_data

library(R6)
library(readxl)
library(dplyr)
library(ggplot2)

PanelAnalyzerR6 <- R6Class("PanelAnalyzerR6",
  public = list(
    data_path = NULL,
    raw_data = NULL,
    results = NULL,
    company_data = NULL,
    
    initialize = function(data_path, sheet_number = 1) {
      self$data_path <- data_path
      self$load_data(sheet_number)
      self$preprocess_data()
    },
    
    load_data = function(sheet_number) {
      cat("Loading data from:", self$data_path, "\n")
      self$raw_data <- read_excel(self$data_path, sheet_number)
      cat("Data loaded successfully. Dimensions:", dim(self$raw_data), "\n")
      invisible(self)
    },
    
    preprocess_data = function() {
      cat("Preprocessing data by company...\n")
      self$company_data <- self$raw_data %>%
        group_by(co) %>%
        group_split()
      cat("Data grouped into", length(self$company_data), "companies\n")
      invisible(self)
    },
    
    # PRIVATE METHOD - Calculate R-squared for one company
    .calculate_company_r2 = function(company_df, window_size = 8) {
      years <- company_df$year
      returns <- company_df$rit
      economic <- company_df$e0
      company_name <- company_df$co[1]
      
      n_points <- length(years)
      company_results <- list()
      
      if (n_points >= window_size) {
        for (start_idx in 1:(n_points - window_size + 1)) {
          end_idx <- start_idx + window_size - 1
          
          window_returns <- returns[start_idx:end_idx]
          window_economic <- economic[start_idx:end_idx]
          
          r_squared <- tryCatch(
            {
              model <- lm(window_returns ~ window_economic)
              summary(model)$r.squared
            },
            error = function(cond) NA
          )
          
          # Store result for this window
          company_results[[length(company_results) + 1]] <- data.frame(
            company = company_name,
            start_year = years[start_idx],
            end_year = years[end_idx],
            r_squared = r_squared,
            n_observations = window_size,
            stringsAsFactors = FALSE
          )
        }
      }
      
      return(company_results)
    },
    
 
   run_analysis = function(window_size = 8) {
      cat("Starting R-squared analysis with window size:", window_size, "\n")
  
     # Single line with map_dfr (automatically binds rows)
      self$results <- purrr::map_dfr(self$company_data, function(company_df) {
      company_name <- company_df$co[1]
      cat("Analyzing company:", company_name, "\n")
    
      company_results <- self$.calculate_company_r2(company_df, window_size)
      bind_rows(company_results)  # Ensure each company's results are a dataframe
    })
  
    cat("Analysis complete. Total windows analyzed:", nrow(self$results), "\n")
    invisible(self)
   },



    get_summary = function() {
      if (is.null(self$results)) {
        stop("Please run analysis first using run_analysis()")
      }
      
      valid_r2 <- na.omit(self$results$r_squared)
      
      summary_stats <- list(
        total_windows = nrow(self$results),
        valid_windows = length(valid_r2),
        mean_r2 = round(mean(valid_r2), 4),
        median_r2 = round(median(valid_r2), 4),
        min_r2 = round(min(valid_r2), 4),
        max_r2 = round(max(valid_r2), 4),
        companies_analyzed = length(unique(self$results$company))
      )
      
      return(summary_stats)
    },
    
    plot_results = function(output_path = "output/") {
      if (!dir.exists(output_path)) {
        dir.create(output_path, recursive = TRUE)
      }
      
      # Distribution of R-squared values
      p1 <- ggplot(self$results, aes(x = r_squared)) +
        geom_histogram(binwidth = 0.05, fill = "steelblue", alpha = 0.8) +
        labs(title = "Distribution of R-squared Values",
             subtitle = paste("Analysis of", length(unique(self$results$company)), "companies"),
             x = "Coefficient of Determination (R-squared)",
             y = "Frequency") +
        theme_minimal()
      
      ggsave(file.path(output_path, "r_squared_distribution.png"), p1, width = 10, height = 6)
      
      # Company analysis count
      company_summary <- self$results %>%
        group_by(company) %>%
        summarise(n_windows = n(), .groups = 'drop') %>%
        arrange(desc(n_windows)) %>%
        head(10)
      
      if (nrow(company_summary) > 0) {
        p2 <- ggplot(company_summary, aes(x = reorder(company, n_windows), y = n_windows)) +
          geom_col(fill = "darkorange", alpha = 0.8) +
          coord_flip() +
          labs(title = "Top 10 Companies by Number of Analysis Windows",
               x = "Company",
               y = "Number of 8-Year Windows") +
          theme_minimal()
        
        ggsave(file.path(output_path, "company_analysis_count.png"), p2, width = 10, height = 6)
      }
      
      cat("Visualizations saved to:", output_path, "\n")
      invisible(self)
    },
    
    get_results = function() {
      return(self$results)
    },
    
    print = function() {
      cat("PanelAnalyzerR6 Object\n")
      cat("Data path:", self$data_path, "\n")
      if (!is.null(self$raw_data)) {
        cat("Data dimensions:", dim(self$raw_data), "\n")
      }
      if (!is.null(self$results)) {
        cat("Results:", nrow(self$results), "analysis windows\n")
        cat("Companies analyzed:", length(unique(self$results$company)), "\n")
      }
    }
  )
)

# ----------------------------
# How to Use the Class
# ----------------------------

cat("=== OBJECT-ORIENTED R-SQUARED ANALYSIS ===\n\n")

# 1. Create analyzer object (automatically loads and preprocesses data)
analyzer <- PanelAnalyzerR6$new("data/corporate_data.xlsx", 1)
analyzer <- PanelAnalyzerR6$new("F://corporate_data.xlsx", 1)

# 2. Run the analysis
analyzer$run_analysis(window_size = 8)

# 3. Get summary statistics
summary_stats <- analyzer$get_summary()
cat("\n=== ANALYSIS SUMMARY ===\n")
print(summary_stats)


# 4. Create visualizations
analyzer$plot_results()

# 5. Access the results dataframe
results_df <- analyzer$get_results()
cat("\nFirst few results:\n")
print(n=summary_stats$total_windows ,results_df)

# 6. Print object info
analyzer$print()

cat("\n=== ANALYSIS COMPLETE ===\n")


