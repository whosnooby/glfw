---@diagnostic disable: undefined-global, undefined-field

------ DEFINTIONS FOR FILE ------
----
-- GLFW_BUILD_DIR - overrides GLFW's build directory.
-- GLFW_OBJ_DIR   - overrides GLFW's intermediate build directory.
-- GLFW_NO_VULKAN - omits building Vulkan functionality for GLFW
----
---------------------------------

local glfw_version = '3.4'

local function wayland_scanner()
  if not os.execute('wayland-scanner -v >/dev/null 2>&1') == 0 then
    error("executable 'wayland-scanner' not in path")
  end

  return 'wayland-scanner'
end

local function gen_wayland(scanner, output_dir, protocol_dir, protocol)
  local protocol_file = protocol_dir .. protocol .. '.xml'

  -- check for protocol file
  if not os.isfile(protocol_file) then
    error("missing wayland protocol file '" .. protocol_file .. "'")
  end

  local out_header = output_dir .. protocol .. '-client-protocol.h'
  local out_code = output_dir .. protocol .. '-client-protocol-code.h'

  -- attempt header generation
  local _, err = os.outputof(scanner .. ' client-header ' .. protocol_file .. ' ' .. out_header)

  -- check if generation failed
  if err ~= 0 then
    error("failed to generate file '" .. out_header .. "'")
  end

  -- log success
  printf("generated '%s' from '%s'", out_header, protocol_file)
  
  -- attempt code generation
  local _, err = os.outputof(scanner .. ' private-code ' .. protocol_file .. ' ' .. out_code)
  
  -- check if generation failed
  if err ~= 0 then
    error("failed to generate file '" .. out_code .. "'")
  end

  -- log success
  printf("generated '%s' from '%s'", out_code, protocol_file)

  -- add generated files to project
  files { out_header, out_code }
end

local function gen_wayland_all()
  printf("generating GLFW wayland files...")

  -- make sure 'wayland-scanner' exists in the current path
  local sc = wayland_scanner()

  -- get GLFW's source files directory
  local glfw_src = os.getcwd() .. '/src/'

  -- get protocols directory
  local wl_protocols_dir = os.getcwd() .. '/deps/wayland/'

  -- generate the files
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'wayland'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'viewporter'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'xdg-shell'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'idle-inhibit-unstable-v1'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'pointer-constraints-unstable-v1'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'relative-pointer-unstable-v1'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'fractional-scale-v1'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'xdg-activation-v1'
  )
  gen_wayland(
    sc,    
    glfw_src,
    wl_protocols_dir,
    'xdg-decoration-unstable-v1'
  )

  printf("generating GLFW wayland files... done!")
end

function glfw_link_deps(no_vulkan)
  filter 'system:linux'
    links {
      'dl',
      'pthread',
    }
    if not no_vulkan then
      links {
        'vulkan'
      }
    end
  filter { 'system:linux', 'not options:glfw-no-x11' }
    includedirs {
      'X11',
      'Xi',
      'Xrandr',
      'Xxf86vm',
    }
end

newoption {
    trigger='glfw-static',
    description='Builds GLFW as a static library'
}

newoption {
  trigger='glfw-no-wayland',
  description='Builds GLFW without Wayland support'
}

newoption {
  trigger='glfw-no-x11',
  description='Builds GLFW without X11 support'
}

if os.target() == 'linux' and
    not _OPTIONS['help'] and
    not _OPTIONS['glfw-no-wayland']
then
  gen_wayland_all()
end

project 'glfw'
  language 'c'
  systemversion 'latest'
  staticruntime 'on'

  -- kind
  filter 'options:glfw-static'
    kind 'staticlib'
  filter 'not options:glfw-static'
    kind 'sharedlib'
    defines { '_GLFW_BUILD_DLL' }
  filter '*'

  targetname ('glfw-'..glfw_version)
  targetdir (GLFW_BUILD_DIR or 'build/%{prj.config}/bin')
  objdir (GLFW_OBJ_DIR or 'build/')

  files {
    'src/context.c',
    'src/init.c',
    'src/input.c',
    'src/monitor.c',
    'src/platform.c',
    'src/window.c',
    'include/GLFW/glfw3.h',
    'include/GLFW/glfw3native.h',
  }

  if not GLFW_NO_VULKAN then
    files {
      'src/vulkan.c',
    }
  end

  glfw_link_deps(GLFW_NO_VULKAN)

  filter 'system:linux'
    pic 'on'

    files {
      'src/glx_context.c',

      'src/linux_joystick.c',
      'src/linux_joystick.h',

      'src/egl_context.c',

      'src/null_init.c',
      'src/null_joystick.c',
      'src/null_joystick.h',
      'src/null_monitor.c',
      'src/null_platform.h',
      'src/null_window.c',

      'src/osmesa_context.c',

      'src/posix_module.c',
      'src/posix_poll.c',
      'src/posix_poll.h',
      'src/posix_thread.c',
      'src/posix_thread.h',
      'src/posix_time.c',
      'src/posix_time.h',

      'src/xkb_unicode.c',
      'src/xkb_unicode.h',
    }

    filter 'not options:glfw-no-wayland'
      files {
          'src/wl_init.c',
          'src/wl_monitor.c',
          'src/wl_platform.h',
          'src/wl_window.c',
      }
      defines { '_GLFW_WAYLAND' }
    filter 'not options:glfw-no-x11'
      files {
          'src/x11_init.c',
          'src/x11_monitor.c',
          'src/x11_platform.h',
          'src/x11_window.c',
      }

      defines { '_GLFW_X11' }
    filter '*'

  filter 'system:windows'
    files {
      'src/wgl_context.c',
      'src/win32_init.c',
      'src/win32_joystick.c',
      'src/win32_monitor.c',
      'src/win32_time.c',
      'src/win32_thread.c',
      'src/win32_window.c',
    }

    defines {
      '_GLFW_WIN32',
      '_CRT_SECURE_NO_WARNINGS',
    }

    links {
      'gdi32',
      'shell32',
      'user32',
    }
  filter '*'
