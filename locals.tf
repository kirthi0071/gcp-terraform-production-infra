# locals.tf (root module)
#
# WHY LOCALS: without them, every module call below would repeat string
# interpolation like "${var.environment}-${var.application_name}-vpc" over
# and over, and a future rename would mean hunting through every file.
# Locals compute a value ONCE, name it, and every module call references the
# name. This is the mechanism that satisfies the "every resource name must
# contain the environment, and it must not be hard-coded in child modules"
# requirement -- the root module computes the name, and passes the finished
# string INTO the module as a plain input variable. The module itself never
# knows or cares whether it's building "qa" or "prod".

locals {
  name_prefix = "${var.environment}-${var.application_name}"

  common_labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
      application = var.application_name
    },
    var.labels
  )
}
