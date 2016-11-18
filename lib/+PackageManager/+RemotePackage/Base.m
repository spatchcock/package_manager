classdef Base < dynamicprops
        
    properties
        name = '';
        source = '';
        installation = struct('tag', '', 'path', '');
    end
    
    methods (Static = true)
        
        function subklass = toSubclass(base)
            
            switch base.source
                case 'github'
                    subklassName = 'Github';
                case 'fileExchange'
                    subklassName = 'FileExchange';
                case 'network'
                    subklassName = 'Network';
            end
             
            subklass = PackageManager.RemotePackage.(subklassName);
            propertyNames = properties(base);
                        
            for pn = 1:length(propertyNames)
                propertyName = propertyNames{pn};
                
                if ~isprop(subklass, propertyName)
                    addprop(subklass, propertyName);
                end
                
                subklass.(propertyName) = base.(propertyName);
            end
        end
        
    end
    
    methods
        
        function addProperty(B, keys, value)            
            if ischar(keys)
                keyString = strtrim(keys);
                [keys, ~] = strsplit(keyString, '.');
            else
                keyString = strjoin(keys, '.');
            end

            if ischar(keys)
               topLevelProperty = keys
            else
               topLevelProperty = keys{1};
            end

            if ~isprop(B, topLevelProperty)
               addprop(B, topLevelProperty);
            end

            if length(keys) > 1
               if isempty(B.(topLevelProperty))
                   B.(topLevelProperty) = struct;
               end

               cmd = sprintf('B.%s = value', keyString);
               evalc(cmd); 
            else
               B.(topLevelProperty) = value;
            end;
        end
        
        function ip = installPath(B, varargin)
            
            if ~isempty(B.installation.path)
                ip = B.installation.path;
            else
                rootPath = PackageManager.Install.rootPath;
            
                for i = 1:2:length(varargin)
                  switch varargin{i}
                    case 'rootPath'
                      rootPath = varargin{i+1};
                  end
                end
                
                ip = [rootPath, '\', B.name, '\versions\'];

                if ~isempty(B.installation.tag)
                    ip = [ip, B.installation.tag];
                else
                    subclassVersionProperty = eval([class(B) '.SubclassVersionProperty']);
                    
                    if ~isempty(subclassVersionProperty) && ~isempty(B.(subclassVersionProperty))
                        ip = [ip, B.(subclassVersionProperty)];
                    else
                        ip = [ip, B.timestamp];
                    end
                end
                                
                B.installation.path = ip;
            end
        end
        
        function clearInstallPath(B)
            B.installation.path = '';
        end
        
        function makeInstallDir(B)
            if exist(B.installPath, 'dir')
                rmpath(genpath(B.installPath));
                rmdir(B.installPath, 's');
            end
            
            mkdir(B.installPath);
        end
        
        function bool = isZipArchive(B)
            [~, ~, ext] = fileparts(B.downloadPath);
            bool = isequal(ext, '.zip');
        end
        
        function ts = timestamp(B)
            ts = datestr(now, 'yyyymmddHHMMSS');
        end
        
        function install(B, varargin)
            recurse = 0;
            
            for i = 1:2:length(varargin)
              switch varargin{i}
                case 'recurse'
                  recurse = varargin{i+1};
              end
            end
            
            if nargin > 0 
                B.clearInstallPath;
                B.installPath(varargin{:});
            end
            
            B.makeInstallDir;
            B.download;
            
            if B.isZipArchive
                unzip(B.downloadPath, B.installPath);
                delete(B.downloadPath);  
            end
            
            if recurse
                dependencies = 0;
                
                % check for dependency file in install location
                dependencyFileName = [B.installPath, '\dependencies'];
                
                if exist(dependencyFileName, 'file')
                    dependencies = 1;
                else
                    % if it is a github install then there will always be
                    % an additional directory layer, look in there
                    installContents = dir(B.installPath);
                    
                    % only if there is a single directory only (no other
                    % dirs or files)
                    % the 3rd entry omits the '.'  and '..' entries
                    if length(installContents) == 3 && installContents(3).isdir
                        dependencyFileName = [B.installPath, '\', installContents(3).name, '\dependencies'];
                        
                        if exist(dependencyFileName, 'file')
                            dependencies = 1;
                        end
                    end
                end
                
                if dependencies
                    dependencyList = PackageManager.RemotePackage.List(dependencyFileName);
                    dependencyList.installAll('recurse',1);
                end
            end
            
            addpath(genpath(B.installPath));
            B.writeInstallInfoToFile(B.installPath);
        end
        
        function s = toString(B)
            
            function writePropertyStructToCell(propertyVector, value)
                
                if ischar(propertyVector)
                    propertyVector = {propertyVector};
                end
                
                if ischar(value)
                    value = strrep(value, '\', '\\');
                end
                
                if isequal(class(value), 'struct')
                    fn = fieldnames(value);
                    
                    for n = 1:length(fn)
                       propertyVector(end+1) = fn(n);                       
                       nextValue = strjoin( ...
                           cellfun(@(x) sprintf('(''%s'')', x), propertyVector, 'UniformOutput', 0), ...
                           '.');
                       
                       writePropertyStructToCell(propertyVector, eval(sprintf('B.%s', nextValue)));
                       propertyVector(end) = [];
                    end
                else
                    lineString = [strjoin(propertyVector, '.'), '=', strtrim(value)];
                    strings{i} = [lineString, '\n'];
                end
            end
            
            m = metaclass(B);
            allProperties = properties(B);
            
            strings = [];            
            
            for i = 1:length(allProperties)
                writePropertyStructToCell(allProperties{i}, B.(allProperties{i}));
            end
            
            s = strjoin(strings, '');
        end
        
        function sizeInBytes = toFile(B, filePath, varargin)
            
            header = '';
            
            for i = 1:2:length(varargin)
              switch varargin{i}
                case 'header'
                  header = varargin{i+1};
              end
            end
            
            str = B.toString;
            
            fid = fopen(filePath, 'w');
            
            if ~isempty(header)
                for r = 1:size(header,1)
                    fprintf(fid, '# %s \n', header{r});
                end
            end
            
            fprintf(fid, '\n');
            fprintf(fid, str);
          
            fclose(fid);
            
            fileInfo    = dir(filePath);
            sizeInBytes = fileInfo.bytes;
        end
        
        function sizeInBytes = writeInstallInfoToFile(B, installPath)
            filePath = [installPath, '\package_manager_install.log'];
            
            header = {};
            header{1} = ['Package installed on ', datestr(now)];
            
            sizeInBytes = B.toFile(filePath, 'header', header);
        end
        
              
    end
    
end
