SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN employment_insurance_and_support_measures END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN employment_insurance_and_support_measures END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN employment_insurance_and_support_measures END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN employment_insurance_and_support_measures END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN employment_insurance_and_support_measures END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN employment_insurance_and_support_measures END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN employment_insurance_and_support_measures END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN employment_insurance_and_support_measures END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN employment_insurance_and_support_measures END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN employment_insurance_and_support_measures END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN employment_insurance_and_support_measures END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN employment_insurance_and_support_measures END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN employment_insurance_and_support_measures END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN employment_insurance_and_support_measures END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN employment_insurance_and_support_measures END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN employment_insurance_and_support_measures END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN employment_insurance_and_support_measures END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
