SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN canada_social_transfer END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN canada_social_transfer END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN canada_social_transfer END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN canada_social_transfer END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN canada_social_transfer END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN canada_social_transfer END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN canada_social_transfer END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN canada_social_transfer END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN canada_social_transfer END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN canada_social_transfer END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN canada_social_transfer END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN canada_social_transfer END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN canada_social_transfer END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN canada_social_transfer END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN canada_social_transfer END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN canada_social_transfer END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN canada_social_transfer END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
