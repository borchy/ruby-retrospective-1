require 'bigdecimal'
require 'bigdecimal/util'
require 'singleton'

class Product
  attr_reader :name
  attr_reader :price
  
  def initialize(name, price)
    @name = name
    @price = price
  end
end

class Inventory
  attr_reader :products
  attr_reader :promotion_per_product
  attr_reader :coupon_by_name
  
  def initialize
    @products = Array.new
    @promotion_per_product = Hash.new
    @coupon_by_name = Hash.new
  end

  def register(name, price, promotion = nil)
    if name.length > 40
      raise "Product name exceeds 40 symbols"
    end
    unless price.to_d.between? 0.01, 999.99
      raise "Price not in the range of 0.01 and 999.99"
    end
    if @products and @products.any? { |product| product.name == name }
      raise "Product already exists"
    end

    @products << Product.new(name, price)
    @promotion_per_product[@products.last] = promotion if promotion
  end

  def new_cart
    Cart.new(self)
  end

  def register_coupon(name, info)
    # TODO coupons vs. coupon_by_name
    @coupon_by_name[name] = info
  end

  def get_product(name)
    @products.find { |product| product.name == name }
  end
end

class Cart
  attr_reader :inventory
  attr_reader :quantity_per_product
  attr_reader :coupon_name
  attr_reader :coupon_type
  attr_reader :coupon_info
  
  def initialize(inventory)
    @inventory = inventory
    @quantity_per_product = Hash.new(0)
  end

  def add(name, quantity = 1)
    product = @inventory.get_product(name)
    
    unless product
      raise "Name already exists"
    end
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
    coupon = CouponFactory.get_coupon(@coupon_type, @coupon_info)
    if coupon
      sum -= coupon.discount(sum)
    else
      sum
    end
  end

  def total_without_coupon
    @quantity_per_product.inject(0) do |sum, (product, quantity)|
      promotion = @inventory.promotion_per_product[product]
      if promotion
        promo = PromotionFactory.get_promotion(promotion.keys[0], promotion)
        sum -= promo.discount(product.price, quantity)
      end
      sum + product.price.to_d * quantity
    end
  end
  
  def invoice
    result = Invoice.header

    @quantity_per_product.each do |product, quantity|
      price = product.price.to_d * quantity

      result += Invoice.line_for_product(product.name, quantity, price)
      promo = @inventory.promotion_per_product[product]
      if promo
        result += Invoice.line_for_promotion(product.price, quantity, product, promo)
      end
    end

    result += coupon_line + Invoice.footer(total)
  end
  
  def coupon_line
    Invoice.line_coupon(@coupon_name, @coupon_type, @coupon_info, total_without_coupon)
  end

  def use(coupon_name)
    raise "Coupon name does not exist" unless @inventory.coupon_by_name[coupon_name]

    @coupon_name = coupon_name
    @coupon_type = @inventory.coupon_by_name[coupon_name].keys[0]
    @coupon_info = @inventory.coupon_by_name[coupon_name].values[0]
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
    res << "| TOTAL                                          |" + "%9.2f" % [sum] + " |\n"
    res += line
  end
  
  def self.line_for_product(name, quantity, price)
    result = String.new
    result += "| " + name + " " * (44 - name.length)
    result += " " * (2 - quantity.to_s.length) + quantity.to_s + " |"
    result += "%9.2f" % [price] + " |\n"
  end
  
  def self.line_for_promotion(price, quantity, product, promotion)
    result = String.new
    promo = PromotionFactory.get_promotion(promotion.keys[0], promotion)
    if promo
      discount = "-" + "%0.2f" % [promo.discount(price, quantity)]
      result += "| " + promo.to_s + " " * (47 - promo.to_s.length) + "|"
      result += " " * (9 - discount.length) + discount + " |" + "\n"
    end
  end
  
  def self.line_coupon(name, type, info, total)
    result = String.new
     if name
       coupon = CouponFactory.get_coupon(type, info)
       coupon_str = "Coupon " + name + " " + "#{coupon.to_s}"
       coupon_dis = "-" + "%0.2f" % [coupon.discount(total)]
       result += "| " + coupon_str + " " * (47 - coupon_str.length) + "|"
       result += " " * (9 - coupon_dis.length) + coupon_dis + " |" + "\n"
     end
     result   
  end
end

module Coupon
  def initialize(coupon_info)
    @coupon_info = coupon_info
  end

  #too sexy for Java interfaces
  def discount
    raise NotImplementedError.new
  end

  class Percent
    include Coupon
    
    def discount(sum)
      sum * @coupon_info / 100.0
    end
  end

  def to_s
    "- #{@coupon_info}% off"
  end

  class Amount
    include Coupon
    
    def discount(sum)
      sum > @coupon_info.to_d ? @coupon_info.to_d : sum
    end

    def to_s
      a = "%0.2f" % [@coupon_info]
      "- #{a} off"
    end
  end
end

class CouponFactory
  include Singleton
  
  def self.get_coupon(type, coupon_info)
    case type
    when :percent
      Coupon::Percent.new(coupon_info)
    when :amount
      Coupon::Amount.new(coupon_info)
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
      free_items_count = quantity / @promo_info.values[0]
      price.to_d * free_items_count
    end

    def to_s
      "  (buy #{@promo_info.values[0] - 1}, get 1 free)"
    end
  end

  class Package
    include Promotion
    
    def discount(price, quantity)
      count = @promo_info.values[0].keys[0]
      result = BigDecimal(@promo_info.values[0].values[0].to_s)
      (quantity / count) * (count * price.to_d * (result / 100))
    end

    def to_s
      a = BigDecimal(@promo_info.values[0].values[0].to_s)
      "  (get #{a.to_i}% off for every #{@promo_info.values[0].keys[0]})"
    end
  end

  class Threshold
    include Promotion
    
    def discount(price, quantity)
      count = @promo_info.values[0].keys[0]
      result = BigDecimal(@promo_info.values[0].values[0].to_s)
      extra = quantity > count ? quantity - count : 0
      extra * price.to_d * (result / 100)
    end

    def to_s
      count = @promo_info.values[0].keys[0]
      a = BigDecimal(@promo_info.values[0].values[0].to_s)
      postfix = number_postfix(count)
      "  (#{a.to_i}% off of every after the #{count}#{postfix})"
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
end

class PromotionFactory
  include Singleton
  
  def self.get_promotion(name, promotion)
    case name
    when :get_one_free
      Promotion::GetOnFree.new(promotion)
    when :package
      Promotion::Package.new(promotion)
    when :threshold
      Promotion::Threshold.new(promotion)
    end
  end
end
