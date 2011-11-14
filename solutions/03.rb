require 'bigdecimal'
require 'bigdecimal/util'
require 'singleton'

class Product
  attr_reader :name
  attr_reader :price
  attr_reader :promotion
  
  def initialize(name, price, promotion)
    raise "Product name exceeds 40 symbols" if name.length > 40
    raise "Price not between 0.01 and 999.99" unless price.between? 0.01, 999.99
    
    @name = name
    @price = price
    @promotion = promotion
  end
end

class Inventory
  attr_reader :products
  attr_reader :coupons
  
  def initialize
    @products = Array.new
    @coupons = Array.new
  end

  def register(name, price, promotion = {})
    if @products and @products.any? { |product| product.name == name }
      raise "Product already exists"
    end

    promo = PromotionFactory.build(promotion)
    @products << Product.new(name, price.to_d, promo)
  end

  def new_cart
    Cart.new(self)
  end

  def register_coupon(name, info)
    coupon_type = info.keys[0]
    coupon_info = info.values[0]
    @coupons << CouponFactory.build(name, coupon_type, coupon_info)
  end
  
  def find_coupon(name) 
    coupons.find(&:name)
  end

  def find_product(name)
    @products.find { |product| product.name == name }
  end
end

class Cart
  attr_reader :quantity_per_product
  attr_reader :coupon
  
  def initialize(inventory)
    @inventory = inventory
    @quantity_per_product = Hash.new(0)
  end

  def add(name, quantity = 1)
    product = @inventory.find_product(name)

    raise "Name already exists" unless product
    if @quantity_per_product[product] + quantity <= 0
      raise "Quantity should be a positive number"
    end
    if @quantity_per_product[product] + quantity > 99
      raise "Quantity should be less or equal to 99"
    end

    @quantity_per_product[product] += quantity
  end

  def total
    sum = total_without_coupon
    if coupon
      sum -= coupon.discount(sum)
    else
      sum
    end
  end

  def total_without_coupon
    @quantity_per_product.inject(0) do |sum, (product, quantity)|
      promotion = product.promotion
      sum -= promotion.discount(product.price, quantity)
      sum + product.price * quantity
    end
  end
  
  def invoice
    result = Invoice.header

    @quantity_per_product.each do |product, quantity|
      price = product.price * quantity
      promo = product.promotion
      
      result += Invoice.line_for_product(product.name, quantity, price)
      result += Invoice.line_for_promotion(quantity, product, promo)
    end

    result += coupon_line + Invoice.footer(total)
  end
  
  def coupon_line
    Invoice.line_coupon(coupon, total_without_coupon)
  end

  def use(coupon_name)
    a_coupon = @inventory.find_coupon(coupon_name)
    raise "Coupon name does not exist" unless a_coupon
    @coupon = a_coupon
  end
end

class Invoice
  include Singleton
  
  def self.line
    "+------------------------------------------------+----------+\n"
  end
  
  def self.header
    res = line
    res << "| Name                                       qty |    price |\n"
    res += line
  end
  
  def self.footer(sum)
    res = line
    res << "| TOTAL" + " " * 42 + "|" + "%9.2f" % [sum] + " |\n"
    res += line
  end
  
  def self.line_for_product(name, quantity, price)
    result = String.new
    result += "| " + name + " " * (44 - name.length)
    result += " " * (2 - quantity.to_s.length) + quantity.to_s + " |"
    result += "%9.2f" % [price] + " |\n"
  end
  
  def self.line_for_promotion(quantity, product, promotion)
    result = String.new
    discount = promotion.discount(product.price, quantity)
    unless discount == 0
      discount_to_s = "-" + "%0.2f" % [discount]
      result += "| " + promotion.to_s + " " * (47 - promotion.to_s.length) + "|"
      result += " " * (9 - discount_to_s.length) + discount_to_s + " |" + "\n"
    else
      result
    end
  end
  
  def self.line_coupon(coupon, total)
    result = String.new
     if coupon
       coupon_str = "Coupon " + coupon.name + " " + "#{coupon.to_s}"
       coupon_dis = "-" + "%0.2f" % [coupon.discount(total)]
       
       result += "| " + coupon_str + " " * (47 - coupon_str.length) + "|"
       result += " " * (9 - coupon_dis.length) + coupon_dis + " |" + "\n"
     end
     result   
  end
end

module Coupon
  def discount
    raise NotImplementedError.new
  end

  class Percent
    include Coupon
    
    attr_reader :name
    attr_reader :percent
    
    def initialize(name, coupon_info)
      @name = name
      @percent = coupon_info
    end
    
    def discount(sum)
      sum * percent / 100.0
    end
  end

  def to_s
    "- #{percent}% off"
  end

  class Amount
    include Coupon
    
    attr_reader :name
    attr_reader :amount
    
    def initialize(name, coupon_info)
      @name = name
      @amount = coupon_info.to_d
    end
    
    def discount(sum)
      sum > amount ? amount : sum
    end

    def to_s
      a = "%0.2f" % [amount]
      "- #{a} off"
    end
  end
end

class CouponFactory
  include Singleton
  
  def self.build(name, type, coupon_info)
    case type
    when :percent
      Coupon::Percent.new(name, coupon_info)
    when :amount
      Coupon::Amount.new(name, coupon_info)
    end
  end
end

module Promotion
  def initialize(promo_info)
    @promo_info = promo_info
  end

  #too sexy for Java interfaces
  def discount(price, quantity)
    raise NotImplementedError.new
  end
  
  class GetOnFree
    include Promotion

    def discount(price, quantity)
      free_items_count = quantity / @promo_info
      price * free_items_count
    end

    def to_s
      "  (buy #{@promo_info - 1}, get 1 free)"
    end
  end

  class Package
    include Promotion
    
    attr_reader :package_size
    attr_reader :percent
    
    def discount(price, quantity)
      @package_size = @promo_info.first[0]
      @percent = @promo_info.first[1].to_s.to_d
      (quantity / @package_size) * (@package_size * price * (@percent / 100))
    end

    def to_s
      "  (get #{percent.to_i}% off for every #{package_size})"
    end
  end

  class Threshold
    include Promotion
    
    attr_reader :threshold
    attr_reader :percent
    
    def discount(price, quantity)
      @threshold = @promo_info.first[0]
      @percent = @promo_info.first[1].to_s.to_d
      
      extra_items = quantity > threshold ? quantity - threshold : 0
      extra_items * price * (percent / 100)
    end

    def to_s
      postfix = number_postfix(threshold)
      "  (#{percent.to_i}% off of every after the #{threshold}#{postfix})"
    end
    
    def number_postfix(number)
      case number
      when 1 then return "st"
      when 2 then return "nd"
      when 3 then return "rd"
      end
      return "th"
    end
  end
  
  class None
    include Promotion
    
    def discount(price, quantity)
      0
    end
  end
end

class PromotionFactory
  include Singleton
  
  def self.build(promotion)
    name, info = promotion.first
    case name
    when :get_one_free
      Promotion::GetOnFree.new(info)
    when :package
      Promotion::Package.new(info)
    when :threshold
      Promotion::Threshold.new(info)
    else
      Promotion::None.new(info)
    end
  end
end
