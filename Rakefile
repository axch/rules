def files
  ["matcher",
   "pattern-directed-invocation",
   "simplification",
   "simplifiers",
   "load",
  ].map do |base|
  "#{base}.scm"
  end
end

task :workbook do
  sh "enscript -M a4 -fCourier-Bold12 -o workbook-a4.ps --file-align=2 README  --color --highlight #{files.join(" ")}"
  sh "enscript -M letter -fCourier-Bold12 -o workbook-letter.ps --file-align=2 README  --color --highlight #{files.join(" ")}"
end
