user = AdminUser.where(email: 'admin@qul.com').first_or_initialize
user.name = "Admin User"
user.password  = "cms-password"
user.confirmed_at = Date.today
user.save

user = User.where(email: 'user@aul.com').first_or_initialize
user.first_name = "Normal"
user.last_name = "User"
user.password  = "cms-password"
user.confirmed_at = Date.today
user.approved=true
user.save
