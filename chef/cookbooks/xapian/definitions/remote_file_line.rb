# Only add a line if it is absent from a file
define :remote_file_line do
  # If the file doesn't exist, first create it
  file params[:name]
  execute "echo '#{params[:line]}' >> #{params[:name]}" do
    not_if { File.open(params[:name]).find { |line| line.strip == params[:line] } }
  end
end