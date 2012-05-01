module Opaz
  module Tools

    PLATFORMS = [:linux, :osx, :win]
    JVSTWRAPPER_VERSION = '1.0beta'
    
    # javac -classpath jar1:jar2:jar3 works on unix, but need ; for separator on windows
    def jar_separator(platform)
      (platform =~ /mswin/ || platform == :win) ? ';' : ':'
    end

    def bundle_url(platform)
      "http://freefr.dl.sourceforge.net/sourceforge/jvstwrapper/jVSTwRapper-Release-#{JVSTWRAPPER_VERSION}-#{platform}.zip"
    end

    # for mirah compilation
    def in_folder(folder)
      old_dir = Dir.pwd
      Dir.chdir(folder)
      yield
    ensure
      Dir.chdir(old_dir)
    end

    def mirahc_command
      cmd = 'mirahc'
      cmd << '.bat' if Config::CONFIG['host_os'] =~ /mswin/
      cmd
    end
    
    def running_platform
      case Config::CONFIG['host_os']
        when /darwin/; :osx
        when /mswin/; :win
        else raise "Unsupported platform for deploy"
      end
    end

    def system!(cmd)
      puts "Launching #{cmd}"
      raise "Failed to launch #{cmd}" unless system(cmd)
    end

    def templatized_file(source,target)
      File.open(target,"w") do |output|
        IO.readlines(source).each do |line|
          line = yield line
          output << line
        end
      end
    end

    def template(platform)
      "templates/#{platform}"
    end
    
    def opaz_jars
      Dir[File.dirname(__FILE__) + "/../libs/*.jar"]
    end

    def download_and_unpack(platform, unzip_folder)
      url = bundle_url(platform)
      zip_file = unzip_folder + "/" + url.split('/').last
      system!("curl #{url} -o #{zip_file} --silent --show-error --location")
      system!("unzip -q #{zip_file} -d #{unzip_folder}")
    end

    def build_folder(plugin_folder)
      plugin_folder + "/build"
    end
    
    def package_plugin(plugin_name,plugin_folder,platforms=PLATFORMS)
      platforms.each do |platform|
        platform_build_folder = build_folder(plugin_folder) + "/#{platform}"
        resources_folder = platform_build_folder + "/wrapper.vst" + (platform == :osx ? "/Contents/Resources" : "")

        # copy platform template
        # cp_r template(platform), platform_build_folder
        cp_r template(platform), build_folder(plugin_folder) 

        # create ini file
        ini_file = resources_folder + "/" + (platform == :osx ? "wrapper.jnilib.ini" : "wrapper.ini")
        File.open(ini_file,"w") do |output|
          content = []
          #content << "ClassPath={WrapperPath}/jVSTwRapper-#{JVSTWRAPPER_VERSION}.jar"

          jars = opaz_jars.find_all { |e| e =~ /jruby|jvst/i }.map { |e| e.split('/').last }
          class_path = jars.find_all { |e| e =~ /jVSTwRapper/i } + ['Plugin.jar']
          
          system_class_path = jars + ['javafx-ui-swing.jar','javafx-sg-swing.jar',
           'javafxrt.jar', 'javafx-ui-common.jar', 'javafx-geom.jar',
           'javafx-sg-common.jar', 'javafx-anim.jar', 'javafx-ui-desktop.jar',
           'decora-runtime.jar','OpazPlug.jar']
          
          content << "ClassPath=" + class_path.map { |jar| "{WrapperPath}/#{jar}"}.join(jar_separator(platform))
          
          # TODO - is order important here ? If not, base ourselves on opaz_jars to stay DRY
          #system_class_path = opaz_jars #["jVSTsYstem-#{JVSTWRAPPER_VERSION}","jVSTwRapper-#{JVSTWRAPPER_VERSION}", "jruby-complete-1.4.0"]
          content << "SystemClassPath=" + system_class_path.map { |jar| "{WrapperPath}/#{jar}"}.join(jar_separator(platform))  + jar_separator(platform) + "{WrapperPath}/"
          content << "IsLoggingEnabled=1"
          content << "JVMOption1=-Djruby.objectspace.enabled=false" #This is the default, so this could eventually be removed
          content << ""
          content << "# JRuby Performance tweaks, enable all for best performance"
          content << "#JVMOption1=-Djruby.compile.fastsend"
          content << "#JVMOption2=-Djruby.compile.fastest"
          content << "#JVMOption3=-Djruby.indexed.methods=true"
          content << "#JVMOption4=-Djruby.compile.mode=FORCE"
          content << "#JVMOption5=-Djruby.compile.fastcase"
          content << ""
          content << "# This UI class will ask the JRuby plugin if it has an editor or not."
          content << "# If there is no editor defined, the GUI will be an empty frame and a separate"
          content << "# IRB window will open so that you can add GUI elements at runtime"
          content << "# Commenting this out means that the plugin UI will be rendered by the host application"
          content << "PluginUIClass=JRubyVSTPluginGUIProxy"
          #content << "PluginUIClass=ToneMatrixGUIDelegator"
          content << ""
          content << "# Alternatively, you can only open the IRB debugging GUI by uncommenting the appropriate line below."
          content << "# No separate plugin GUI will be shown. "
          content << "#PluginUIClass=IRBPluginGUI"
          content << ""
          content << "AttachToNativePluginWindow=1"
          content << ""
          content << "# Reload .rb files when they have changed, while the plugin is running"
          content << "# --> ctrl-s in your editor changes the running plugin :-)"
          content << "ReloadRubyOnChanges=1"
          content << ""
          yield content # offer the caller a way to hook its stuff in here
          content.each { |e| output << e + "\n"}
        end

        # add classes and jars - crappy catch all (include .rb file even for pure-java stuff), but works so far
        resources = opaz_jars
        resources << Dir[build_folder(plugin_folder) + "/common/*"]
        resources.flatten.each { |f| cp f, resources_folder }

        # create Info.plist (osx only)
        if platform == :osx
          plist_file = platform_build_folder + "/wrapper.vst/Contents/Info.plist"
          plist_content = IO.read(plist_file).gsub!(/<key>(\w*)<\/key>\s+<string>([^<]+)<\/string>/) do
            key,value = $1, $2
            value = plugin_name+".jnilib" if key == 'CFBundleExecutable'
            value = plugin_name if key == 'CFBundleName'
            "<key>#{key}</key>\n	<string>#{value}</string>"
          end
          File.open(plist_file,"w") { |output| output << plist_content }
        end

        # rename to match plugin name - two pass - first the directories, then the files
        (0..1).each do |pass|
          Dir[platform_build_folder+"/**/wrapper*"].partition { |f| File.directory?(f) }[pass].each do |file|
            File.rename(file,file.gsub(/wrapper/,plugin_name))
          end
        end
      end
    end
    
  end
end
