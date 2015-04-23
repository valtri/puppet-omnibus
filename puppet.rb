class PuppetGem < FPM::Cookery::Recipe
  description 'Puppet gem stack'

  name 'puppet'
  version '3.7.5'

  source "nothing", :with => :noop

  platforms [:ubuntu, :debian] do
    build_depends 'libaugeas-dev', 'pkg-config', 'libyaml-0-2'
    depends 'libaugeas0', 'pkg-config', 'libyaml-0-2'
  end

  platforms [:fedora, :redhat, :centos] do
    build_depends 'augeas-devel', 'pkgconfig', 'libyaml-0-2'
    depends 'augeas-libs', 'pkgconfig', 'libyaml'
  end

  def build
    # Install gems using the gem command from destdir
    gem_install 'facter',      '2.4.3'
    gem_install 'json_pure',   '1.8.2'
    gem_install 'hiera',       '1.3.4'
    gem_install 'deep_merge',  '1.0.1'
    gem_install 'rgen',        '0.7.0'
    gem_install 'ruby-augeas', '0.5.0'
    gem_install 'ruby-shadow', '2.3.4'
    gem_install 'gpgme',       '2.0.7'
    gem_install name,          version

    # Download init scripts and conf
    build_files

    # Patch the puppet and facter (filthy hack)
    system("sed -e 's,\"/etc/puppet\",\"#{destdir}/etc/puppet\",' -i #{destdir}/lib/ruby/gems/2.1.0/gems/puppet-3.7.5/lib/puppet/util/run_mode.rb")
    system("sed -e 's,\"/var/lib/puppet\",\"#{destdir}/var/lib/puppet\",' -i #{destdir}/lib/ruby/gems/2.1.0/gems/puppet-3.7.5/lib/puppet/util/run_mode.rb")
    system("sed -e 's,\"/etc/facter/facts.d\",\"#{destdir}/etc/facter/facts.d\",' -i #{destdir}/lib/ruby/gems/2.1.0/gems/facter-2.4.3/lib/facter/util/config.rb")
  end

  def install
    # Install init-script and puppet.conf
    install_files

    # Provide 'safe' binaries in /opt/<package>/bin like Vagrant does
    rm_rf "#{destdir}/../bin"
    destdir('../bin').mkdir
    destdir('../bin').install workdir('omnibus.bin'), 'puppet'
    destdir('../bin').install workdir('omnibus.bin'), 'facter'
    destdir('../bin').install workdir('omnibus.bin'), 'hiera'

    destdir('var/lib/puppet').mkdir
    destdir('var/log/puppet').mkdir
    destdir('var/run/puppet').mkdir

    # Symlink binaries to PATH using update-alternatives
    with_trueprefix do
      create_post_install_hook
      create_pre_uninstall_hook
    end
  end

  private

  def gem_install(name, version = nil)
    v = version.nil? ? '' : "-v #{version}"
    cleanenv_safesystem "#{destdir}/bin/gem install --no-ri --no-rdoc #{v} #{name}"
  end

  platforms [:ubuntu, :debian] do
    def build_files
      system "curl -L -O https://raw.githubusercontent.com/puppetlabs/puppet/#{version}/ext/debian/puppet.conf"
      system "curl -L -O https://raw.githubusercontent.com/puppetlabs/puppet/#{version}/ext/debian/puppet.init"
      system "curl -L -O https://raw.githubusercontent.com/puppetlabs/puppet/#{version}/ext/debian/puppet.default"
      # Set the real daemon path in initscript defaults
      system "echo DAEMON=#{destdir}/bin/puppet >> puppet.default"
      system "sed -e 's,=/var,=#{destdir}/var,' -i puppet.conf"
    end
    def install_files
      destdir('etc/puppet/modules').mkdir
      destdir('etc/puppet').install builddir('puppet.conf') => 'puppet.conf'
      destdir('etc/init.d').install builddir('puppet.init') => 'puppet'
      destdir('etc/default').install builddir('puppet.default') => 'puppet'
      chmod 0755, destdir('etc/init.d/puppet')
    end
  end

  platforms [:fedora, :redhat, :centos] do
    def build_files
      safesystem "curl -L -O https://raw.githubusercontent.com/puppetlabs/puppet/#{version}/ext/redhat/puppet.conf"
      safesystem "curl -L -O https://raw.githubusercontent.com/puppetlabs/puppet/#{version}/ext/redhat/client.init"
      safesystem "curl -L -O https://raw.githubusercontent.com/puppetlabs/puppet/#{version}/ext/redhat/client.sysconfig"
      # Set the real daemon path in initscript defaults
      safesystem "echo PUPPETD=#{destdir}/bin/puppet >> client.sysconfig"
    end
    def install_files
      destdir('etc/puppet/modules').mkdir
      destdir('etc/puppet').install builddir('puppet.conf') => 'puppet.conf'
      destdir('etc/init.d').install builddir('client.init') => 'puppet'
      destdir('etc/sysconfig').install builddir('client.sysconfig') => 'puppet'
      chmod 0755, destdir('etc/init.d/puppet')
    end
  end

  def create_post_install_hook
    File.open(builddir('post-install'), 'w', 0755) do |f|
      f.write <<-__POSTINST
#!/bin/sh
set -e

BIN_PATH="#{destdir}/bin"
BINS="puppet facter hiera"

for BIN in $BINS; do
  update-alternatives --install /usr/bin/$BIN $BIN $BIN_PATH/$BIN 100
done

exit 0
      __POSTINST
    end
  end

  def create_pre_uninstall_hook
    File.open(builddir('pre-uninstall'), 'w', 0755) do |f|
      f.write <<-__PRERM
#!/bin/sh
set -e

BIN_PATH="#{destdir}/bin"
BINS="puppet facter hiera"

if [ "$1" != "upgrade" ]; then
  for BIN in $BINS; do
    update-alternatives --remove $BIN $BIN_PATH/$BIN
  done
fi

exit 0
      __PRERM
    end
  end

end
