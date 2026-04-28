# name: newsletter-archive
# about: Displays a PDF newsletter archive on /c/newsletters/70 with admin upload support
# version: 1.0.0
# authors: Your Forum Team
# url: https://github.com/your-org/discourse-newsletter-archive

register_asset "stylesheets/newsletter-archive.scss" if File.exist?(File.join(__dir__, "assets/stylesheets/newsletter-archive.scss"))
