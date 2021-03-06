component "ruby" do |pkg, settings, platform|
  pkg.version "2.1.9"
  pkg.md5sum "d9d2109d3827789344cc3aceb8e1d697"
  pkg.url "http://buildsources.delivery.puppetlabs.net/ruby-#{pkg.get_version}.tar.gz"

  if platform.is_windows?
    pkg.add_source "http://buildsources.delivery.puppetlabs.net/windows/elevate/elevate.exe", sum: "bd81807a5c13da32dd2a7157f66fa55d"
    pkg.add_source "file://resources/files/windows/elevate.exe.config", sum: "a5aecf3f7335fa1250a0f691d754d561"
  end

  pkg.replaces 'pe-ruby'
  pkg.replaces 'pe-ruby-mysql'
  pkg.replaces 'pe-rubygems'
  pkg.replaces 'pe-libyaml'
  pkg.replaces 'pe-libldap'
  pkg.replaces 'pe-ruby-ldap'
  pkg.replaces 'pe-rubygem-gem2rpm'

  base = 'resources/patches/ruby'
  pkg.apply_patch "#{base}/libyaml_cve-2014-9130.patch"

  # These are a pretty smelly hack, and they run the risk of letting tests
  # based on the generated data (that should otherwise fail) pass
  # erroneously. We should probably fix the "not shipping our compiler"
  # problem that led us to do this sooner rather than later.
  #   Ryan McKern, 26/09/2015
  #   Reference notes:
  #   - 6b089ed2: Provide a sane rbconfig for AIX
  #   - 8e88a51a: (RE-5401) Add rbconfig for solaris 11 sparc
  #   - 8f10f5f8: (RE-5400) Roll rbconfig for solaris 11 back to 2.1.6
  #   - 741d18b1: (RE-5400) Update ruby for solaris 11 i386
  #   - d09ed06f: (RE-5290) Update ruby to replace rbconfig for all solaris
  #   - bba35c1e: (RE-5290) Update ruby for a cross-compile on solaris 10
  rbconfig_info = {
    'powerpc-ibm-aix5.3.0.0' => {
      :sum => "5c445630ac67ddf61d16eb47a4ff955b",
      :target_double => "powerpc-aix5.3.0.0",
    },
    'powerpc-ibm-aix6.1.0.0' => {
      :sum => "82ee3719187cba9bbf6f4b7088b52305",
      :target_double => "powerpc-aix6.1.0.0",
    },
    'powerpc-ibm-aix7.1.0.0' => {
      :sum => "960fb03d7818fec612f3be598c6964d2",
      :target_double => "powerpc-aix7.1.0.0",
     },
    'powerpc-linux-gnu' => {
      :sum => "763f316f8f43878d1f3bd5aa6bbe36e8",
      :target_double => "powerpc-linux",
    },
    's390x-linux-gnu' => {
      :sum => "3bb93ed43fddc4807347a988cbb2e0c1",
      :target_double => "s390x-linux",
    },
    'i386-pc-solaris2.10' => {
      :sum => "9078034711ef1b047dcb7416134c55ae",
      :target_double => 'i386-solaris2.10',
    },
    'sparc-sun-solaris2.10' => {
      :sum => "3fbceb4f70e086a6df52c206ca17211b",
      :target_double => 'sparc-solaris2.10',
    },
    'i386-pc-solaris2.11' => {
      :sum => "224822682a570aceec965c75ca00d882",
      :target_double => 'i386-solaris2.11',
    },
    'sparc-sun-solaris2.11' => {
      :sum => "f2a40c4bff028dffc880a40b2806a361",
      :target_double => 'sparc-solaris2.11',
    }
  }

  if platform.is_aix?
    pkg.apply_patch "#{base}/aix_ruby_2.1_libpath_with_opt_dir.patch"
    pkg.apply_patch "#{base}/aix_ruby_2.1_fix_proctitle.patch"
    pkg.apply_patch "#{base}/aix_ruby_2.1_fix_make_test_failure.patch"
    pkg.environment "CC" => "/opt/pl-build-tools/bin/gcc"
    pkg.environment "LDFLAGS" => settings[:ldflags]
    pkg.build_requires "libedit"
    pkg.build_requires "runtime"

    # This normalizes the build string to something like AIX 7.1.0.0 rather
    # than AIX 7.1.0.2 or something
    special_flags = "--build=#{settings[:platform_triple]}"
  end

  if platform.is_windows?
    pkg.apply_patch "#{base}/windows_ruby_2.1_update_to_rubygems_2.4.5.patch"
    pkg.apply_patch "#{base}/windows_fixup_generated_batch_files.patch"
    pkg.apply_patch "#{base}/windows_remove_DL_deprecated_warning.patch"
    pkg.apply_patch "#{base}/windows_ruby_2.1_update_to_rubygems_2.4.5.1.patch"
  end

  # Cross-compiles require a hand-built rbconfig from the target system
  if platform.is_solaris? || platform.is_aix? || platform.is_huaweios? || platform.architecture == "s390x"
    pkg.add_source "file://resources/files/rbconfig-#{settings[:platform_triple]}.rb", sum: rbconfig_info[settings[:platform_triple]][:sum]
  end

  pkg.build_requires "openssl"

  if platform.is_deb?
    pkg.build_requires "zlib1g-dev"
  elsif platform.is_aix?
    pkg.build_requires "http://osmirror.delivery.puppetlabs.net/AIX_MIRROR/zlib-devel-1.2.3-4.aix5.2.ppc.rpm"
  elsif platform.is_rpm?
    pkg.build_requires "zlib-devel"
  elsif platform.is_windows?
    pkg.build_requires "pl-zlib-#{platform.architecture}"
  end

  if platform.is_huaweios? || platform.architecture == "s390x"
    pkg.build_requires 'pl-ruby'
    special_flags = "--with-baseruby=#{settings[:host_ruby]}"
    pkg.build_requires 'runtime' if platform.is_huaweios?
    pkg.environment "PATH" => "#{settings[:bindir]}:$$PATH"
    pkg.environment "CC" => "/opt/pl-build-tools/bin/#{settings[:platform_triple]}-gcc"
    pkg.environment "LDFLAGS" => "-Wl,-rpath=/opt/puppetlabs/puppet/lib"
  end

  if platform.is_osx?
    pkg.environment "optflags" => settings[:cflags]
  end

  if platform.is_solaris?
    if platform.architecture == "sparc"
      if platform.os_version == "10"
        # ruby1.8 is not new enough to successfully cross-compile ruby 2.1.x (it doesn't understand the --disable-gems flag)
        pkg.build_requires 'ruby20'
      elsif platform.os_version == "11"
        pkg.build_requires 'pl-ruby'
      end

      special_flags = "--with-baseruby=#{settings[:host_ruby]}"
    end
    pkg.build_requires 'libedit'
    pkg.build_requires 'runtime'
    pkg.environment "PATH" => "#{settings[:bindir]}:/usr/ccs/bin:/usr/sfw/bin:$$PATH:/opt/csw/bin"
    pkg.environment "CC" => "/opt/pl-build-tools/bin/#{settings[:platform_triple]}-gcc"
    pkg.environment "LDFLAGS" => "-Wl,-rpath=/opt/puppetlabs/puppet/lib"
  end

  if platform.is_windows?
    pkg.build_requires "pl-gdbm-#{platform.architecture}"
    pkg.build_requires "pl-iconv-#{platform.architecture}"
    pkg.build_requires "pl-libffi-#{platform.architecture}"
    pkg.build_requires "pl-pdcurses-#{platform.architecture}"

    pkg.environment "PATH" => "$$(cygpath -u #{settings[:gcc_bindir]}):$$(cygpath -u #{settings[:tools_root]}/bin):$$(cygpath -u #{settings[:bindir]}):$$PATH"
    pkg.environment "CYGWIN" => settings[:cygwin]

    special_flags = "CPPFLAGS='-DFD_SETSIZE=2048' debugflags=-g"
  end


  # Here we set --enable-bundled-libyaml to ensure that the libyaml included in
  # ruby is used, even if the build system has a copy of libyaml available
  pkg.configure do
    [
      "bash configure \
        --prefix=#{settings[:prefix]} \
        --with-opt-dir=#{settings[:prefix]} \
        --enable-shared \
        --enable-bundled-libyaml \
        --disable-install-doc \
        --disable-install-rdoc \
        #{settings[:host]} \
        #{special_flags}"
     ]
  end

  pkg.build do
    "#{platform[:make]} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"
  end

  pkg.install do
    "#{platform[:make]} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"
  end

  if platform.is_windows?
    pkg.install_file "../elevate.exe", "#{settings[:bindir]}/elevate.exe"
    pkg.install_file "../elevate.exe.config", "#{settings[:bindir]}/elevate.exe.config"
  end
  if platform.is_solaris? || platform.is_aix? || platform.is_huaweios? || platform.architecture == "s390x"
    # Here we replace the rbconfig from our ruby compiled with our toolchain
    # with an rbconfig from a ruby of the same version compiled with the system
    # gcc. Without this, the rbconfig will be looking for a gcc that won't
    # exist on a user system and will also pass flags which may not work on
    # that system.
    # We also disable a safety check in the rbconfig to prevent it from being
    # loaded from a different ruby, because we're going to do that later to
    # install compiled gems.
    #
    # On AIX we build everything using our own GCC. This means that gem
    # installing a compiled gem would not work without us shipping that gcc.
    # This tells the ruby setup that it can use the default system gcc rather
    # than our own.
    target_dir = File.join(settings[:libdir], "ruby", "2.1.0", rbconfig_info[settings[:platform_triple]][:target_double])
    sed = "sed"
    sed = "gsed" if platform.is_solaris?
    sed = "/opt/freeware/bin/sed" if platform.is_aix?
    pkg.install do
      [
        "#{sed} -i 's|raise|warn|g' #{target_dir}/rbconfig.rb",
        "mkdir -p #{settings[:datadir]}/doc",
        "cp #{target_dir}/rbconfig.rb #{settings[:datadir]}/doc",
        "cp ../rbconfig-#{settings[:platform_triple]}.rb #{target_dir}/rbconfig.rb",
      ]
    end
  end
end
