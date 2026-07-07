-- ==========================================
-- TeknoyCart Database Schema Migration Script
-- Target Platform: Supabase / PostgreSQL
-- Team Code: 45 | Capstone Project 1
-- ==========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. ENUMS & TYPE DEFINITIONS
-- ==========================================
CREATE TYPE user_role AS ENUM ('BUYER', 'SELLER', 'ADMIN');
CREATE TYPE product_status AS ENUM ('ACTIVE', 'INACTIVE', 'PENDING');
CREATE TYPE order_status AS ENUM ('INQUIRY_SENT', 'APPROVED', 'REJECTED', 'PAYMENT_SUBMITTED', 'PAYMENT_VERIFIED', 'READY_FOR_PICKUP', 'COMPLETED', 'CANCELLED');
CREATE TYPE payment_method AS ENUM ('GCASH', 'CASH_ON_PICKUP');
CREATE TYPE payment_proof_status AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');
CREATE TYPE inquiry_type AS ENUM ('AVAILABILITY', 'CUSTOM_ORDER', 'BULK_PRICING', 'OTHER');

-- ==========================================
-- 2. PRIMARY TABLES
-- ==========================================

-- USERS (Core Profile & RBAC)
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'BUYER',
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    failed_attempts INT NOT NULL DEFAULT 0,
    lock_until TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Strict email domain constraint (SRS FR-01/FR-02)
    CONSTRAINT check_institutional_email CHECK (
        email LIKE '%@cit.edu' OR email LIKE '%@cit.edu'
    )
);

-- STORE PROFILES (Seller store descriptions)
CREATE TABLE IF NOT EXISTS store_profiles (
    store_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID NOT NULL UNIQUE,
    store_name VARCHAR(255) NOT NULL,
    description TEXT NULL,
    banner_url TEXT NULL,
    contact_number VARCHAR(20) NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- CATEGORIES
CREATE TABLE IF NOT EXISTS categories (
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) UNIQUE NOT NULL,
    icon_url TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID NOT NULL,
    category_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT NULL,
    base_price DECIMAL(10, 2) NOT NULL CHECK (base_price >= 0),
    status product_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE RESTRICT
);

-- PRODUCT IMAGES
CREATE TABLE IF NOT EXISTS product_images (
    image_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- PRODUCT VARIANTS
CREATE TABLE IF NOT EXISTS product_variants (
    variant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    variant_name VARCHAR(100) NOT NULL, -- e.g., 'Size'
    variant_value VARCHAR(100) NOT NULL, -- e.g., 'Large'
    additional_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (additional_price >= 0),
    sku VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- INVENTORY
CREATE TABLE IF NOT EXISTS inventory (
    inventory_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    variant_id UUID NOT NULL UNIQUE,
    stock_qty INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    reserved_qty INT NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0),
    low_stock_threshold INT NOT NULL DEFAULT 5,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id) ON DELETE CASCADE
);

-- INQUIRIES
CREATE TABLE IF NOT EXISTS inquiries (
    inquiry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    buyer_id UUID NOT NULL,
    product_id UUID NOT NULL,
    variant_id UUID NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    inquiry_type inquiry_type NOT NULL DEFAULT 'AVAILABILITY',
    message TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id) ON DELETE CASCADE
);

-- CHATS (Direct Message rooms linked to inquiry)
CREATE TABLE IF NOT EXISTS chats (
    chat_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inquiry_id UUID NOT NULL UNIQUE,
    buyer_id UUID NOT NULL,
    seller_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (inquiry_id) REFERENCES inquiries(inquiry_id) ON DELETE CASCADE,
    FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- MESSAGES
CREATE TABLE IF NOT EXISTS messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    content TEXT NULL,
    image_url TEXT NULL, -- Receipt screenshots / proof attachments
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (chat_id) REFERENCES chats(chat_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ORDERS
CREATE TABLE IF NOT EXISTS orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inquiry_id UUID NOT NULL,
    buyer_id UUID NOT NULL,
    seller_id UUID NOT NULL,
    variant_id UUID NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    payment_method payment_method NULL,
    status order_status NOT NULL DEFAULT 'INQUIRY_SENT',
    pickup_location VARCHAR(255) NULL,
    reservation_expires_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (inquiry_id) REFERENCES inquiries(inquiry_id) ON DELETE CASCADE,
    FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(variant_id) ON DELETE CASCADE
);

-- PAYMENT PROOFS (Manual GCash uploads)
CREATE TABLE IF NOT EXISTS payment_proofs (
    proof_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL UNIQUE,
    image_url TEXT NOT NULL, -- Cloudinary link
    status payment_proof_status NOT NULL DEFAULT 'PENDING',
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP WITH TIME ZONE NULL,
    
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- ==========================================
-- 3. INDEXES FOR PERFORMANCE (NFR-01/NFR-03)
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id);

-- ==========================================
-- 4. DOMAIN EMAIL STRICT DOMAIN CHECK TRIGGER
-- ==========================================
CREATE OR REPLACE FUNCTION verify_user_email_domain()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email NOT LIKE '%@cit.edu' AND NEW.email NOT LIKE '%@cit.edu' THEN
        RAISE EXCEPTION 'Registration restricted to official Cebu Institute of Technology - University (@cit.edu / @cit.edu) institutional accounts.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_email_domain_check
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION verify_user_email_domain();

-- =============================================================
-- 5. REALTIME & SECURITY INITIALIZATION
-- =============================================================
-- Enable realtime updates for messaging & chat logs
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;

-- Disable RLS for development/testing convenience (re-enable in production)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiries DISABLE ROW LEVEL SECURITY;

