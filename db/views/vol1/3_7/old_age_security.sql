SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN old_age_security_benefits END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN old_age_security_benefits END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN old_age_security_benefits END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN old_age_security_benefits END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN old_age_security_benefits END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN old_age_security_benefits END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN old_age_security_benefits END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN old_age_security_benefits END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN old_age_security_benefits END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN old_age_security_benefits END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN old_age_security_benefits END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN old_age_security_benefits END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN old_age_security_benefits END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN old_age_security_benefits END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN old_age_security_benefits END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN old_age_security_benefits END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN old_age_security_benefits END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;