require "sqlite3"
require "reverse_markdown"
require "fileutils"

module NotesExporter
  class Export
    def run(path:, output_path:, include_tags:)
      path = File.expand_path(path)

      db = SQLite3::Database.new(path)

      db.execute("select ZFOLDER, ZDATEEDITED, ZBODY, Z_PK from ZNOTE") do |row|
        folder_id = row[0]

        # lol Apple & Core Data, why u start at 2001-01-01 :joy:
        core_data_time_offset = 978325200

        updated = Time.at(row[1] + core_data_time_offset)

        body_id = row[2]
        notes_pk = row[3]

        folder_name = db.execute("select ZNAME from ZFOLDER WHERE Z_PK = #{folder_id}").first[0]

        db.execute("select ZHTMLSTRING from ZNOTEBODY WHERE Z_PK = #{body_id}") do |body_row|
          # The Apple database stores stuff in HTML (lol)
          # so we gotta convert it to something human-readable
          # => markdown

          html_text = body_row[0]
          markdown_text = ReverseMarkdown.convert(html_text)
          markdown_text << "\n\n##{folder_name}" if include_tags

          folder_output_path = File.join(output_path, folder_name, "#{notes_pk}.md")
          general_output_path = File.join(output_path, "all_notes", "#{notes_pk}.md")
          
          [folder_output_path, general_output_path].each do |full_output_path|
            FileUtils.mkdir_p(File.expand_path("..", full_output_path))
            File.write(full_output_path, markdown_text)

            # Change the modified dates to the correct ones
            FileUtils.touch(full_output_path, mtime: Time.at(updated))

            puts "Successfully generated #{full_output_path}"
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  NotesExporter::Export.new.run(
    path: "~/Downloads/jd/com.apple.Notes/Data/Library/Notes/NotesV7.storedata",
    output_path: "./fx_export/",
    include_tags: true
  )
end
