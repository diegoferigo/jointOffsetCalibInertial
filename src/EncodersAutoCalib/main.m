%% clear all variables and close all previous figures
clear
close all
clc

%% Global parameters

% Function used to optimise the offsets through an optimisation method like
% *fminunc*, *fmincon*, ...
costFunction = @costFunctionSigma;
%costFunction = @costFunctionSigmaProjOnEachLink;

% Optimisation configuration
[optimFunction,options] = getOptimConfig();
startPoint2Boundary = 5*pi/180; % 5 deg

% A random init selects randomly an ordered subset of samples from the whole data
% set bucket.
number_of_random_init = 5;
subsetVec_size_frac = 0.1; % subset size = 1/10 total data set size


%% define the joints to calibrate and the sensor codes and links they are attached to
jointsToCalibrate.parts = {'left_leg'};
jointsToCalibrate.partJoints = {};
jointsToCalibrate.partJointsInitOffsets = {};
mtbSensorCodes_list = {};
mtbSensorLink_list = {};

mtbInvertedFrames = {};
% correction for MTB mounted upside-down
global real_R_model;
real_R_model  = [-1, 0, 0;  ...
                  0,-1, 0; ...
                  0, 0, 1];

global mtbSensorAct_left_leg;
mtbSensorAct_left_leg = {false,false, ...
                         true,true, ...
                         false, ...
                         true,true, ...
                         true,false,   ...
                         false,false,   ...
                         true};

run jointsNsensorsDefinitions;


%% define offsets for parsing Linear Acceleration data from MTB accelerometers
%
% Refer to wiki:
% https://github.com/robotology/codyco-modules/wiki/External-Inertial-Sensors-for-iCubGenova02
%
% a = (n  6.0  (a1  b1 t1 x1 y1 z1)   .... (an  bn tn xn yn xn))
% n  = number of sensors published on the port
% ai = pos of sensor ... see enum type
% bi = accel (1) or gyro (2)
% ti = ?
% 
% | size  | 1 |  1  |   6  |            6           | ...
% | offset| 1 |  2  | 3..8 |2+6*(i-1)+1..2+6*(i-1)+6| ...
% | Field | n | 6.0 |a1..z1| ai  bi  ti  xi  yi  zi | ...
%
HEADER_LENGTH = 2;
FULL_ACC_SIZE = 6;
LIN_ACC_1RST_IDX = 4;
LIN_ACC_LAST_IDX = 6;


%% PROCESS EACH PART INDEPENDENTLY
%
for part = 1 : length(jointsToCalibrate.parts)

    %% define joint codes and links for current part
    %
    mtbSensorCodes = mtbSensorCodes_list{part};
    mtbSensorLink = mtbSensorLink_list{part};
    
    %% generate indices and labels for the mtb sensors (Accelerometers)
    %
    nrOfMTBAccs = length(mtbSensorLink);
    mtbIndices = {};
    for i = 1:nrOfMTBAccs
        % Indexes for linear acceleration
        mtbIndices{i} = strcat(num2str(HEADER_LENGTH+FULL_ACC_SIZE*(i-1)+LIN_ACC_1RST_IDX), ...
            ':', ...
            num2str(HEADER_LENGTH+FULL_ACC_SIZE*(i-1)+LIN_ACC_LAST_IDX));
    end

    mtbSensorFrames = {};
    for i = 1:nrOfMTBAccs
        % there is no naming convention yet. ex of sensor frame:
        % [r_upper_leg_mtb_acc_11b3]
        mtbSensorFrames{i} = strcat(mtbSensorLink{i},'_mtb_acc_',mtbSensorCodes{i});
    end

    mtbSensorLabel = {};
    for i = 1:nrOfMTBAccs
        % ex of sensor label:
        % [11b3_acc]
        mtbSensorLabel{i} = strcat(mtbSensorCodes{i},'_acc');
    end


    %% Parsing configuration
    %
    % the fields of "data" are created here on the fly.
    %
    data.nsamples  = 1000; %number of samples
    data.plot      = 0;
    data.ini       = 2;    %seconds to be skipped at the start
    data.end       = 28;   %seconds to reach the end of the movement
    data.diff_imu  = 0;    %derivate the angular velocity of the IMUs
    data.diff_q    = 0;    %derivate the angular velocity of the IMUs


    %% strucutre from files and model
    data.path        = '../../data/calibration/dumper/iCubGenova02_#1/';
%    data.path        = '../../data/calibration/dumperExample/iCubGenova02/';
    data.parts       = {};
    data.labels      = {};
    data.frames      = {};
    data.isInverted  = {};
    data.ndof        = {};
    data.index       = {};
    data.type        = {};
    data.visualize   = {};

    %% add mtb sensors
    for i = 1:nrOfMTBAccs
        data = addSensToData(data, jointsToCalibrate.parts{part}, mtbSensorFrames{i}, mtbInvertedFrames{i} , mtbSensorLabel{i} , 3, mtbIndices{i}, 'inertialMTB', 1*data.plot);
    end

    %% add joint measurements
    data = addSensToData(data, jointsToCalibrate.parts{part}, '', '' , [jointsToCalibrate.parts{part} '_state'] , 6, '1:6', 'stateExt:o' , 1*data.plot);

    data = loadData(data);


    %% Create the estimator and model...
    %
    % Create an estimator class, load the respective model from URDF file and
    % set the robot state constant parameters

    % Create estimator class
    estimator = iDynTree.ExtWrenchesAndJointTorquesEstimator();

    % Load model and sensors from the URDF file
    estimator.loadModelAndSensorsFromFile('../models/iCubGenova02/iCubFull.urdf');

    % Check if the model was correctly created by printing the model
    estimator.model().toString()

    %% Optimization
    %

    subsetVec_size = round(data.nsamples*subsetVec_size_frac);
    Dq0 = cell2mat(jointsToCalibrate.partJointsInitOffsets(part))';
    lowerBoundary = Dq0 - startPoint2Boundary;
    upperBoundary = Dq0 + startPoint2Boundary;
    
    % run minimisation for every random subset of data.
    % 1 subset <=> all measurements for a given timestamp <=>1 column index of
    % table `q_xxx`, `dq_xxx`, `ddq_xxx`, `y_xxx_acc`, ...
    for i = 1 : number_of_random_init
        
        % define a random subset: 10 % of the total set of instants
        subsetVec_idx = randsample(data.nsamples, subsetVec_size);
        subsetVec_idx = sort(subsetVec_idx);
        
        % optimize
        funcProps = functions(optimFunction);
        funcName = funcProps.function;
        switch funcName
            case 'fminunc'
                [optimalDq(:, i),  resnorm(1,i), exitflag(1,i), output(1,i)] = optimFunction(@(Dq) costFunction(Dq, part, jointsToCalibrate, ...
                    data, subsetVec_idx, estimator, ...
                    optimFunction), ...
                    Dq0, options);
            case 'lsqnonlin'
                [optimalDq(:, i), resnorm(1,i), ~, exitflag(1,i), output(1,i), lambda(1,i)] = optimFunction(@(Dq) costFunction(Dq, part, jointsToCalibrate, ...
                    data, subsetVec_idx, estimator, ...
                    optimFunction), ...
                    Dq0, lowerBoundary, upperBoundary, options);
            otherwise
        end
        optimalDq(:, i) = mod(optimalDq(:, i)+pi, 2*pi)-pi;
    end
    
    % Standard deviation
    std_optDq = std(optimalDq,0,2);
    
    fprintf('Final optimization results. Each column stands for a random init of the data subset.\n');
    fprintf('Optimal offsets Dq (in radians):\n');
    optimalDq
    fprintf('Mean cost (in (m.s^{-2})^2):\n');
     resnorm/(nrOfMTBAccs*length(subsetVec_idx))
    fprintf('optimization function exit flag:\n');
    exitflag
    fprintf('other optimization info:\n');
    output
    fprintf('Standard deviation for each joint offset:\n');
    std_optDq
    
end

