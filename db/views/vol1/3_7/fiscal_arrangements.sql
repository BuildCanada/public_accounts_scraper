SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN fiscal_arrangements END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN fiscal_arrangements END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN fiscal_arrangements END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN fiscal_arrangements END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN fiscal_arrangements END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN fiscal_arrangements END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN fiscal_arrangements END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN fiscal_arrangements END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN fiscal_arrangements END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN fiscal_arrangements END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN fiscal_arrangements END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN fiscal_arrangements END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN fiscal_arrangements END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN fiscal_arrangements END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN fiscal_arrangements END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN fiscal_arrangements END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN fiscal_arrangements END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
