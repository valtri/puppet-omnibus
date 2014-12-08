class PuppetOmnibus < FPM::Cookery::Recipe
  homepage 'https://github.com/andytinycat/puppet-omnibus'

  section 'Utilities'
  name 'puppet-omnibus'
  version '3.7.3'
  description 'Puppet Omnibus package'
  revision 0
  vendor 'fpm'
  maintainer '<github@tinycat.co.uk>'
  license 'Apache 2.0 License'

  source '', :with => :noop

  omnibus_package true
  omnibus_dir     "/opt/#{name}"
  omnibus_recipes 'ruby',
                  'puppet'

  # Set up paths to initscript and config files per platform
  platforms [:ubuntu, :debian] do
    config_files "#{omnibus_dir}/embedded/etc/puppet/puppet.conf",
                 "#{omnibus_dir}/embedded/etc/init.d/puppet",
                 "#{omnibus_dir}/embedded/etc/default/puppet"
  end
  platforms [:fedora, :redhat, :centos] do
    config_files "#{omnibus_dir}/embedded/etc/puppet/puppet.conf",
                 "#{omnibus_dir}/embedded/etc/init.d/puppet",
                 "#{omnibus_dir}/embedded/etc/sysconfig/puppet"
  end
  omnibus_additional_paths config_files

  def build
    # Nothing
  end

  def install
    # Nothing
  end

end

