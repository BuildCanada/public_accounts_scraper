SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN total END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN total END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN total END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN total END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN total END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN total END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN total END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN total END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN total END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN total END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN total END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN total END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN total END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN total END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN total END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN total END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN total END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
