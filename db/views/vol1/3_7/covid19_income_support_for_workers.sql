SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN covid19_income_support_for_workers END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN covid19_income_support_for_workers END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN covid19_income_support_for_workers END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN covid19_income_support_for_workers END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN covid19_income_support_for_workers END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN covid19_income_support_for_workers END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN covid19_income_support_for_workers END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN covid19_income_support_for_workers END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN covid19_income_support_for_workers END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN covid19_income_support_for_workers END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN covid19_income_support_for_workers END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN covid19_income_support_for_workers END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN covid19_income_support_for_workers END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN covid19_income_support_for_workers END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN covid19_income_support_for_workers END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN covid19_income_support_for_workers END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN covid19_income_support_for_workers END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
