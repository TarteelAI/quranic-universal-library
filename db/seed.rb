user = User.where(email: 'admin@cms.com').first_or_initialize
user.first_name = "Admin"
user.last_name = "User"
user.confirmed_at = Date.today
user.password  = "cms-password"
user.confirmed_at = Date.today
user.approved=true
user.save
