INSERT INTO roles(name) VALUES ('USER'),('ADMIN');

-- default (system) categories
INSERT INTO categories(user_id,name,kind) VALUES
 (NULL,'Food','EXPENSE'),(NULL,'Transport','EXPENSE'),(NULL,'Shopping','EXPENSE'),
 (NULL,'Bills','EXPENSE'),(NULL,'Health','EXPENSE'),(NULL,'Entertainment','EXPENSE'),
 (NULL,'Education','EXPENSE'),(NULL,'Other','EXPENSE'),
 (NULL,'Salary','INCOME'),(NULL,'Freelance','INCOME'),(NULL,'Other Income','INCOME');

INSERT INTO assets(symbol,name,asset_type,price,risk_level) VALUES
 ('TECH','Tech Leaders Stock','STOCK',182.40,4),
 ('BANK','Regional Bank Stock','STOCK',54.10,3),
 ('IDXF','Global Index Fund','FUND',102.75,2),
 ('GOVB','Government Bond 5Y','BOND',99.80,1),
 ('BTC','Bitcoin (simulated)','CRYPTO',64000.00,5),
 ('ETH','Ethereum (simulated)','CRYPTO',3200.00,5);
-- Demo user (demo@finance.app / Demo@1234), accounts and ~90 days of
-- transactions are created by the backend DemoDataSeeder on first start
-- (BCrypt hash is generated at runtime, never hard-coded).
