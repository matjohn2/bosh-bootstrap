require "bosh-bootstrap/microbosh_providers"

# Configures and deploys (or re-deploys) a micro bosh.
# A "micro bosh" is a single VM containing all necessary parts of bosh
# and is deployed from the terminal; rather than from another bosh.
#
# Usage:
#   microbosh = Bosh::Bootstrap::Microbosh.new(project_path)
#   settings = Settingslogic.new({
#     "provider" => {"name" => "aws", "credentials" => {...}},
#     "address" => {"ip" => "1.2.3.4"},
#     "bosh" => {
#       "name" => "test-bosh",
#       "stemcell" => "ami-123456",
#       "salted_password" => "452435hjg2345hjg2435ghk3452"
#     }
#   })
#   microbosh.deploy("aws", settings)
class Bosh::Bootstrap::Microbosh
  include FileUtils

  attr_reader :base_path
  attr_reader :provider

  def initialize(base_path)
    @base_path = base_path
  end

  def deploy(provider_name, settings)
    mkdir_p(base_path)
    chdir(base_path) do
      setup_base_path
      initialize_microbosh_provider(provider_name)
      create_microbosh_yml(settings)
      deploy_or_update(settings.bosh.stemcell)
    end
  end

  protected
  def setup_base_path
    gempath = File.expand_path("../../..", __FILE__)
    File.open("Gemfile", "w") do |f|
      f << <<-RUBY
source 'https://rubygems.org'
source 'https://s3.amazonaws.com/bosh-jenkins-gems/'

gem "bosh-bootstrap", path: #{gempath}
      RUBY
    end
    rm_rf "Gemfile.lock"
    sh "bundle install"
  end

  def initialize_microbosh_provider(provider_name)
    @provider ||= begin
      require "bosh-bootstrap/microbosh_providers/#{provider_name}"
      klass = Bosh::Bootstrap::MicroboshProviders.provider_class(provider_name)
      klass.new(File.expand_path("deployments/micro_bosh.yml"))
    end
  end

  def create_microbosh_yml(settings)
    provider.create_microbosh_yml(settings)
  end

  def deploy_or_update(stemcell)
    sh "bundle exec bosh micro deploy #{stemcell}"
  end
end