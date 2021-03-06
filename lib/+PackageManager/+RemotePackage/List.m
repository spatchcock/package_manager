classdef List < handle
    %DEPENDENCYLIST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        filePath = '';
        packages = {};
    end
    
    methods
        
        function L = List(filePath)
            if exist('filePath', 'var')
                L.fromFile(filePath);
            end           
        end
        
        function fromFile(L, filePath)
            file = textread(filePath,'%s','delimiter','\n');

            % Strip commented rows
            % Yuk.
            commentedRows = find(...
                not(...
                    cellfun(@isempty,...
                        cellfun(@(x) regexp(x, '^#'), file, 'UniformOutput',0)...
                    )...
                )...
            );
        
            file(commentedRows) = [];

            % Parse individual entries - delimited by empty lines
            delimitingRows = find(cellfun(@(x) isempty(strtrim(x)), file));

            if isempty(delimitingRows)
                delimitingRows(1) = size(file,1)+1;
            end
            
            if delimitingRows(end) ~= size(file,1)+1
                delimitingRows(end+1,1) = size(file,1)+1;
            end
            
            if delimitingRows(1) == 1
                delimitingRows(1) = [];
            end
                                    
            adjacentRows = find(diff(delimitingRows) == 1);
            delimitingRows(adjacentRows+1) = [];
            packageCount = size(delimitingRows,1);
            
            startRowIndex = 1;
                        
            for d = 1:packageCount
                rows = file(startRowIndex:delimitingRows(d)-1);
                
                base = PackageManager.RemotePackage.Base;
                
                for r = 1:size(rows,1)
                    if  regexp(rows{r}, '^#') | regexp(rows{r}, '^\s+$') | isempty(rows{r})
                        continue;
                    end

                    if  regexp(rows{r}, '.*=.*')
                       [strs, ~] = strsplit(rows{r}, '=');
                       
                       base.addProperty(strtrim(strs{1}), strtrim(strs{2}));
                    end  
                end
                
                package = PackageManager.RemotePackage.Base.toSubclass(base);
                
                L.packages{d} = package;
                startRowIndex = delimitingRows(d)+1;
            end

            L.filePath = filePath;
        end
        
        function s = size(DL)
            s = size(DL.packages,2);
        end
        
        function installAll(DL, varargin)
            for d = 1:DL.size
                try
                    DL.packages{d}.install(varargin{:});
                catch Err
                    disp(['The installation of ', DL.packages{d}.name, ' failed with the following message...'])
                    warning(Err.message)
                    continue
                end
            end
        end
                    
    end
    
end

