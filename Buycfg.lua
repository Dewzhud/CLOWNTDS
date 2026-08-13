return {

    {
        Tower    = "Boomerang",
        Priority = 1,
        Conditions = {
            MinLevel      = 3,        -- Level ขั้นต่ำ
            MaxLevel      = 10,      -- Level สูงสุด (ถ้าเกินนี้ไม่ซื้อ)
            MinCoins      = 300,      -- Coin ขั้นต่ำที่ต้องมีก่อนซื้อ
            MaxCoins      = 99999,    -- Coin สูงสุด (ถ้าเกินนี้ไม่ซื้อ เก็บเงินไว้ใช้อย่างอื่น)
            RequireTower  = {"Demoman"},       -- ต้องมี Tower พวกนี้อยู่ก่อน (dependency)
            OnlyIfMode    = {},       -- ซื้อเฉพาะ Mode เหล่านี้เท่านั้น (ว่าง = ทุก Mode)
            SkipIfMode    = {},       -- ข้ามถ้า Mode ตรงกับรายการนี้
            OneTimeOnly   = true,     -- true = ซื้อครั้งเดียวแล้วจบ ไม่ซื้อซ้ำรอบหน้า
            BuyLimit      = 1,         
    },
    },
