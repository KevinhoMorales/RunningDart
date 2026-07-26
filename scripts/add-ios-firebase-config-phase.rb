#!/usr/bin/env ruby
# frozen_string_literal: true

# Añade al target Runner la fase que copia el GoogleService-Info.plist del
# flavor. Es idempotente: se puede volver a ejecutar tras regenerar el proyecto.

require 'xcodeproj'

PHASE_NAME = 'Copy Firebase config for flavor'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Runner' }
abort 'No se encontró el target Runner' if target.nil?

existing = target.shell_script_build_phases.find { |p| p.name == PHASE_NAME }
phase = existing || target.new_shell_script_build_phase(PHASE_NAME)

phase.shell_path = '/bin/sh'
phase.shell_script = <<~SCRIPT
  # El bundle id es lo que distingue dev de prod, igual que en AppEnvironment.
  case "${PRODUCT_BUNDLE_IDENTIFIER}" in
    *.dev) FLAVOR=dev ;;
    *) FLAVOR=prod ;;
  esac

  SOURCE="${SRCROOT}/config/${FLAVOR}/GoogleService-Info.plist"
  DESTINATION="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

  if [ ! -f "${SOURCE}" ]; then
    echo "error: falta ${SOURCE}"
    exit 1
  fi

  cp "${SOURCE}" "${DESTINATION}"
SCRIPT
phase.input_paths = [
  '$(SRCROOT)/config/dev/GoogleService-Info.plist',
  '$(SRCROOT)/config/prod/GoogleService-Info.plist'
]
phase.output_paths = [
  '$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist'
]

# Tiene que correr después de copiar recursos, o el plist de prod lo pisaría.
target.build_phases.delete(phase)
resources_index = target.build_phases.index(target.resources_build_phase)
target.build_phases.insert(resources_index + 1, phase)

# El plist legacy en Runner/ no debe ir en Copy Bundle Resources: choca con esta fase.
legacy_plist = project.files.find { |f| f.path == 'GoogleService-Info.plist' }
if legacy_plist
  target.resources_build_phase.files_references.delete(legacy_plist)
  legacy_plist.remove_from_project
end

project.save
puts "Fase '#{PHASE_NAME}' configurada en el target Runner."
