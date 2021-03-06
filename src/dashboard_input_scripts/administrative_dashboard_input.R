## Purpose of this script is to generate svg plots and Rdata with tables input for html report

# Load RData from argus_dashboard_raw_input_script.R
load("src/assets/admin_report_raw_input.RData")

# Clean assets ####
# Remove previous plots
unlink(administrative_report_plots_paths)

# Preprocess data ####  
last_12_weeks_report_status <- admin_report_input$reportingValues_W12 %>%
  round_review_report()

last_12_weeks_level_2 <- last_12_weeks_report_status %>%
  dplyr::filter(level == 1) %>%
  mutate(
    year = ifelse(week <= 8, 2018, 2017), # TODO This is temporary - year column needs to be in the raw data
    year_week = paste0("'", substr(year, 3, 4), " - W", week)) %>%
  arrange(year, week)

min_year <- min(last_12_weeks_level_2$year)
max_year <- max(last_12_weeks_level_2$year)

min_week <- last_12_weeks_level_2 %>%
  filter(year == min_year) %>%
  pull(week) %>% min()

max_week <- last_12_weeks_level_2 %>%
  filter(year == max_year) %>%
  pull(week) %>% max()

last_12_weeks_level_1_long <- last_12_weeks_level_2 %>%
  select(Id_Site, year_week, week, compReport, timeReport, reference) %>% 
  gather(key = label, value = number, -Id_Site, -year_week, -week, -reference) %>%
  mutate(label = recode_report(label))

# Create plots ####
central_plots <- last_12_weeks_level_1_long %>%
  plot_reporting_central_level(plot_colors,
                               x_title = i18n$t("epi_week_nb"),
                               y_title = '%')

central_plots

ggsave(file = paste0(assets_path, "central_plot.svg"), plot = central_plots, width = 10)

# Overall reporting plot # JG the use of plotly should be replaced by ggplot2 to produce the svg plots. 
overall_12_weeks_report_status <- admin_report_input$reportingValues_W12_overall %>%
  round_review_report()

first_intermediate_level <- overall_12_weeks_report_status$level %>% max()

count_levels <- overall_12_weeks_report_status %>%  group_by(level) %>% count()
count_first_intermediate_level <- count_levels %>% filter(level == first_intermediate_level) %>% pull(n)

selected_level <- ifelse(count_first_intermediate_level < max_intermediate_levels,
                         first_intermediate_level, first_intermediate_level + 1)

parent_sites <- overall_12_weeks_report_status %>%
  dplyr::filter(level %in% c(1, selected_level)) %>%
  select(compReport, timeReport, Id_Site, reference, FK_ParentId) %>% 
  gather(key = label, value = number, -Id_Site, -reference, -FK_ParentId) %>%
  mutate(label = recode_report(label),
         parent_label = factor(paste(FK_ParentId, reference, sep = "_"))) %>%
  arrange(parent_label)

order_sites <- unique(parent_sites$parent_label)

reporting_parent_sites <- parent_sites %>%
  plot_1st_itermediate_level(plot_colors = plot_colors,
                             x_title = '',
                             y_title = '%')

reporting_parent_sites

ggsave(file = paste0(assets_path, "reporting_parent_sites.svg"), plot = reporting_parent_sites, width = 10)

## Review plot # JG the use of plotly should be replaced by ggplot2 to produce the svg plots. 
reviewing_sites <- overall_12_weeks_report_status

reviewing_sites_long <- reviewing_sites %>%
  select(compReview, timeReview, FK_ParentId, reference, level) %>% 
  gather(key = label, value = number, -reference, -FK_ParentId, -level) %>%
  mutate(label = recode_review(label),
         number = ifelse(is.nan(number), 0, number)) %>%
  arrange(level)

order_sites_review <- unique(reviewing_sites_long$reference)

weekly_review_plots <- reviewing_sites_long %>% plot_1st_itermediate_level(
  plot_colors = plot_colors,
  x_title = '',
  y_title = '%') +
  scale_x_discrete(limits = order_sites_review)

weekly_review_plots

ggsave(file = paste0(assets_path, "review_plots.svg"), plot = weekly_review_plots, width = 10)

# Generate tables ####
# Silent sites
sites_no_report_3weeks <- admin_report_input$noReport_W3 %>%
  select(name_parentSite, siteName, contact, phone) %>%
  dplyr::filter(!siteName %in% unique(admin_report_input$noReport_W8$siteName))

data.table::setnames(sites_no_report_3weeks,
                    old = names(sites_no_report_3weeks),
                    new = c(i18n$t("name_parentSite"), i18n$t("siteName"), i18n$t("contact"),
                            i18n$t("phone")))

sites_no_report_8weeks <- admin_report_input$noReport_W8 %>%
  select(name_parentSite, siteName, contact, phone)

data.table::setnames(sites_no_report_8weeks,
                    old = names(sites_no_report_8weeks),
                    new = c(i18n$t("name_parentSite"), i18n$t("siteName"), i18n$t("contact"),
                            i18n$t("phone")))

## Save output for markdown report ####
save(min_week, max_week, min_year, max_year,
  sites_no_report_3weeks, sites_no_report_8weeks, file = paste0(assets_path, "admin_report.RData"))
