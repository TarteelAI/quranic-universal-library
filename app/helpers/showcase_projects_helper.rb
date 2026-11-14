require 'zlib'

module ShowcaseProjectsHelper
  # Soft tints for the letter tile shown when a project has no logo.
  # Full class strings are kept here so Tailwind picks them up.
  MONOGRAM_COLORS = [
    'bg-emerald-50 text-emerald-700 border-emerald-100',
    'bg-sky-50 text-sky-700 border-sky-100',
    'bg-amber-50 text-amber-700 border-amber-100',
    'bg-rose-50 text-rose-700 border-rose-100',
    'bg-violet-50 text-violet-700 border-violet-100',
    'bg-teal-50 text-teal-700 border-teal-100'
  ].freeze

  # CRC32 keeps the color stable across processes (String#hash is seeded per process).
  def showcase_monogram_classes(project)
    MONOGRAM_COLORS[Zlib.crc32(project.name.to_s) % MONOGRAM_COLORS.size]
  end
end
