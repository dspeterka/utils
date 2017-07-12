function [imData,sizx,sizy]=sbigread2(varargin);
%reads tiff files in Matlab bigger than 4GB, allows reading from sframe to sframe+num2read-1 frames of the tiff - in other words, you can read page 200-300 without rading in from page 1.
%based on a partial solution posted on Matlab Central (http://www.mathworks.com/matlabcentral/answers/108021-matlab-only-opens-first-frame-of-multi-page-tiff-stack)
%Darcy Peterka 2014, v1.0
%Darcy Peterka 2014, v1.1
%Darcy Peterka 2016, v1.2
%Eftychios Pnevmatikakis 2016, v1.3 (added hdf5 support)
%Darcy Peterka 2016, v1.4
%Darcy Peterka 2016, v1.5
%Darcy Peterka 2016, v1.6 (bugs to dp2403@columbia.edu)
%Program checks for bit depth, whether int or float, and byte order.  Assumes uncompressed, non-negative (i.e. unsigned) data.
%
% Usage:  my_data=bigread('path_to_data_file, start frame, num to read);
% "my_data" will be your [M,N,frames] array.
%Will do mild error checking on the inputs - last three inputs are optional -
%if nargin == 2, then assumes second is number of frames to read, and reads
%till the end
%Checks to see if imageJ generated tif, then uses info in imageJ generated
%image description to load the files based on offset and image number.
%


%get image type
path_to_file=strjoin(varargin(1));
[~,~,ext] = fileparts(path_to_file);

% If a tif file, do the following...
if strcmpi(ext,'.tiff') || strcmpi(ext,'.tif');
    info = imfinfo(path_to_file);
    
    %find the apparent number of images in the stack
    % not extensively error checked, but seems to work on all imagej generated images so far (9/13/16)
    if strfind(info(1).ImageDescription,'ImageJ')
        junk1=regexp(info(1).ImageDescription,'images=\d*','match');
        junk2=strjoin(junk1);
        aa=strread(junk2,'%*s %d','delimiter','=');
        numFrames=aa;
        num_tot_frames=numFrames;
        
        if nargin<=3
            if nargin<2
                sframe = 1;
            else
                sframe=cell2mat(varargin(2));
            end
            num2read=numFrames-sframe+1;
        end
        if nargin==3
            num2read=cell2mat(varargin(3));
        end
        
        % mild error checking on read start and stops
        if sframe<=0
            sframe=1;
        end
        if num2read<1
            num2read=1;
        end
        if sframe>num_tot_frames
            sframe=num_tot_frames;
            num2read=1;
            display('starting frame has to be less than number of total frames...');
        end
        if (num2read+sframe<= num_tot_frames+1)
            lastframe=num2read+sframe-1;
        else
            num2read=numFrames-sframe+1;
            lastframe=num_tot_frames;
            display('Hmmm...just reading from starting frame until the end');
        end
        
        %image data bit depth and type
        bd=info.BitDepth;
        he=info.ByteOrder;
        bo=strcmp(he,'big-endian');
        if (bd==64)
            form='double';
            for_mult=8;
        elseif(bd==32)
            form='single'
            for_mult=4;
        elseif (bd==16)
            form='uint16';
            for_mult=2;
        elseif (bd==8)
            form='uint8';
            for_mult=1;
        end
        
        %set up cell to hold image data
        framenum=num2read;
        imData=cell(1,framenum);
        
        % Use low-level File I/O to read the file
        fp = fopen(path_to_file , 'rb');
        
        
        %image x and y dims
        he_w=info.Width;
        sizx=he_w;
        he_h=info.Height;
        sizy=he_h;
        
        % set offset to first image
        first_offset=info.StripOffsets;
        ofds=zeros(numFrames);
        %compute frame offsets
        for i=1:numFrames
            ofds(i)=first_offset+(i-1)*he_w*he_h*for_mult;
            %ofds(i)
        end
        
        sframemsg = ['Reading from frame ',num2str(sframe),' to frame ',num2str(num2read+sframe-1),' of ',num2str(num_tot_frames), ' total frames'];
        disp(sframemsg)
        pause(.2)
        %go to start of first strip
        %fseek(fp, ofds(1), 'bof');
        % mul is set to > 1 for debugging only...do not change unless you want to seg fault :)
        mul=1;
        
        % uint reads with different byte orders
        if strcmpi(form,'uint16') || strcmpi(form,'uint8')
            if(bo)
                for cnt = sframe:lastframe
                    %cnt;
                    fseek(fp,ofds(cnt),'bof');
                    tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-be')';
                    imData{cnt-sframe+1}=cast(tmp1,form);
                end
            else
                for cnt=sframe:lastframe
                    % cnt;
                    fseek(fp,ofds(cnt),'bof');
                    tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-le')';
                    imData{cnt-sframe+1}=cast(tmp1,form);
                end
            end
            
            % floating point reads with different byte orders
        elseif strcmpi(form,'single')
            if(bo)
                for cnt = sframe:lastframe
                    %cnt;
                    fseek(fp,ofds(cnt),'bof');
                    tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-be')';
                    imData{cnt-sframe+1}=cast(tmp1,'single');
                end
            else
                for cnt = sframe:lastframe
                    %cnt;
                    fseek(fp,ofds(cnt),'bof');
                    tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-le')';
                    imData{cnt-sframe+1}=cast(tmp1,'single');
                end
            end
            %don't know why I cast to single precision in write step...probably for a reason once, but can change to "cast(tmp1,'double')" if you really want double...
        elseif strcmpi(form,'double')
            if(bo)
                for cnt = sframe:lastframe
                    %cnt;
                    fseek(fp,ofds(cnt),'bof');
                    tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-be.l64')';
                    imData{cnt-sframe+1}=cast(tmp1,'single');
                end
            else
                for cnt = sframe:lastframe
                    %cnt;
                    fseek(fp,ofds(cnt),'bof');
                    tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-le.l64')';
                    imData{cnt-sframe+1}=cast(tmp1,'single');
                end
            end
        end
        
        
    else
        blah=size(info);
        numFrames= blah(1);
        num_tot_frames=numFrames;
        
        if (nargin <=3)
            
            %should add more error checking for args... very ugly code below.  works
            %for me after midnight though...
            if nargin<=3
                if nargin<2
                    sframe = 1;
                else
                    sframe=cell2mat(varargin(2));
                end
                num2read=numFrames-sframe+1;
            end
            if nargin==3
                num2read=cell2mat(varargin(3));
            end
            if sframe>num_tot_frames
                sframe=num_tot_frames;
                num2read=1;
                display('starting frame has to be less than number of total frames...');
            end
            if (num2read+sframe<= num_tot_frames+1)
                lastframe=num2read+sframe-1;
            else
                num2read=numFrames-sframe+1;
                lastframe=num_tot_frames;
                display('Hmmm...just reading from starting frame until the end');
            end
            
            
            bd=info.BitDepth;
            he=info.ByteOrder;
            bo=strcmp(he,'big-endian');
            if (bd==64)
                form='double';
            elseif(bd==32)
                form='single'
            elseif (bd==16)
                form='uint16';
            elseif (bd==8)
                form='uint8';
            end
            
            
            % Use low-level File I/O to read the file
            fp = fopen(path_to_file , 'rb');
            % The StripOffsets field provides the offset to the first strip. Based on
            % the INFO for this file, each image consists of 1 strip.
            
            he=info.StripOffsets;
            %finds the offset of each strip in the movie.  Image does not have to have
            %uniform strips, but needs uniform bytes per strip/row.
            idss=max(size(info(1).StripOffsets));
            ofds=zeros(numFrames);
            for i=1:numFrames
                ofds(i)=info(i).StripOffsets(1);
                %ofds(i)
            end
            sframemsg = ['Reading from frame ',num2str(sframe),' to frame ',num2str(num2read+sframe-1),' of ',num2str(num_tot_frames), ' total frames'];
            disp(sframemsg)
            pause(.2)
            %go to start of first strip
            fseek(fp, ofds(1), 'bof');
            %framenum=numFrames;
            framenum=num2read;
            imData=cell(1,framenum);
            
            he_w=info.Width;
            sizx=he_w;
            he_h=info.Height;
            sizy=he_h;
            % mul is set to > 1 for debugging only
            mul=1;
            if strcmpi(form,'uint16') || strcmpi(form,'uint8')
                if(bo)
                    for cnt = sframe:lastframe
                        %cnt;
                        fseek(fp,ofds(cnt),'bof');
                        tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-be')';
                        imData{cnt-sframe+1}=cast(tmp1,form);
                    end
                else
                    for cnt=sframe:lastframe
                        % cnt;
                        fseek(fp,ofds(cnt),'bof');
                        tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-le')';
                        imData{cnt-sframe+1}=cast(tmp1,form);
                    end
                end
            elseif strcmpi(form,'single')
                if(bo)
                    for cnt = sframe:lastframe
                        %cnt;
                        fseek(fp,ofds(cnt),'bof');
                        tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-be')';
                        imData{cnt-sframe+1}=cast(tmp1,'single');
                    end
                else
                    for cnt = sframe:lastframe
                        %cnt;
                        fseek(fp,ofds(cnt),'bof');
                        tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-le')';
                        imData{cnt-sframe+1}=cast(tmp1,'single');
                    end
                end
            elseif strcmpi(form,'double')
                if(bo)
                    for cnt = sframe:lastframe
                        %cnt;
                        fseek(fp,ofds(cnt),'bof');
                        tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-be.l64')';
                        imData{cnt-sframe+1}=cast(tmp1,'single');
                    end
                else
                    for cnt = sframe:lastframe
                        %cnt;
                        fseek(fp,ofds(cnt),'bof');
                        tmp1 = fread(fp, [he_w he_h*mul], form, 0, 'ieee-le.l64')';
                        imData{cnt-sframe+1}=cast(tmp1,'single');
                    end
                end
            end
            
        end
    end
    %ieee-le.l64
    
    imData=cell2mat(imData);
    imData=reshape(imData,[he_h*mul,he_w,framenum]);
    fclose(fp);
    display('Finished reading images')
    
    
elseif strcmpi(ext,'.hdf5') || strcmpi(ext,'.h5');
    info = hdf5info(path_to_file);
    dims = info.GroupHierarchy.Datasets.Dims;
    if nargin < 2
        sframe = 1;
    end
    if nargin < 3
        num2read = dims(end)-sframe+1;
    end
    num2read = min(num2read,dims(end)-sframe+1);
    imData = h5read(path_to_file,'/mov',[ones(1,length(dims)-1),sframe],[dims(1:end-1),num2read]);
else
    error('Unknown file extension. Only .tif and .hdf5 files are currently supported');
end