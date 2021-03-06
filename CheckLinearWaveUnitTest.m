%file = '/Users/jearly/Desktop/InternalWavesConstantN_UnitTest_128_128_65.nc';
file = '/Volumes/Data/InternalWaveSimulations/InternalWavesSingleLowMode_64_64_65-.nc'; phi0 = 0; sign = -1;
file = '/Volumes/Data/InternalWaveSimulations/InternalWavesSingleLowMode_64_64_65+.nc'; phi0 = 0; sign = 1;
file = '/Volumes/Data/InternalWaveSimulations/InternalWavesSingleHighMode_64_64_65-.nc'; phi0 = 0; sign = -1;
%file = '/Users/jearly/Documents/Models/InternalWaves/single_wave_unit_test_pascale.nc';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%	Adjustable parameters
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

latitude = 43.2886;
Lx = 10e3;
Ly = 10e3;
Lz = 100;
Nx = 64;
Ny = 64;
Nz = 65;

xModeNumber = 25;	% Cycles in the x-direction. This sets the wavelength.
zModeNumber = 25;	% Vertical eigenmode. Mode 1 means first baroclinic mode.
U=max(max(max(double(squeeze(ncread(file, 'u', [1 1 1 1], [Inf Inf Inf 1], [1 1 1 1]))))));				% wave speed, in meters per second
stratification = 'constant';	% Choose either 'constant' or 'realistic';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%	Work
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

xDomain = linspace(0,Lx-Lx/Nx,Nx)';	% This dimension is assumed periodic
yDomain = linspace(0,Ly-Ly/Ny,Ny)';	% This dimension is assumed periodic
zDomain = linspace(-Lz,0,Nz)';

if strcmp( stratification, 'constant')
	N2_0 = 1.7227e-4;
	rho = -N2_0*(1025/9.81)*zDomain+1025;
elseif strcmp( stratification, 'realistic')
	load('RepresentativeProfile.mat');
	rho = interp1(z,rho,zDomain);
elseif strcmp( stratification, 'exponential')
    rho_0 = 1027;   % [kg/m3]
    N0 = .0188;     % surface value [1/s]
    Nbot = .0034;   % bottom value [1/s]
    B = 59;         % [m]
    g = 9.81;       % [m/s2]
    rho = rho_0 -(rho_0/g)*(zDomain*Nbot^2 + (B/2)*(N0^2-Nbot^2)*exp(2*zDomain/B) );
else
	display('Invalid choice of stratification!'); quit;
end

f0 = 2*(7.2921e-5)*sin(latitude*pi/180);	% Coriolis parameter.
wavelength = Lx/xModeNumber;				% Wavelength, in meters, of the wave.
k = 2*pi/wavelength;						% Wavenumber.
phi = 0;									% phase				

[F, G, h, N2] = InternalWaveModesFromDensityProfile_Spectral( rho, zDomain, zDomain, k, latitude, 'max_u', 'rigid_lid' );
drho_dz = -(rho(1)/9.81)*N2;

omega = sign*sqrt(9.81*h(zModeNumber)*k*k+f0*f0);
period = abs(2*pi/omega);
disp(sprintf('The wave period is set to %.1f hours.', period/3600))
disp(sprintf('The wave amplitude is %.2f the phase speed.', abs(U/(omega/k))))

% These now have dimensions, Lx x Ly x Lz
[y,x,z] = meshgrid(yDomain,xDomain,zDomain);

% Convert these 1D, z-dependent variable into 3D variables
F3D= repmat(reshape(F(:,zModeNumber),[1 1 Nz]),Nx,Ny,1);
G3D= repmat(reshape(G(:,zModeNumber),[1 1 Nz]),Nx,Ny,1);
rho3D = repmat(reshape(rho,[1 1 Nz]),Nx,Ny,1);
drho_dz3D = repmat(reshape(drho_dz',[1 1 Nz]),Nx,Ny,1);

t = ncread(file, 'time');
%t=t(find(t<=2700));

zeta_diff_max = zeros(length(t),1);
rho_diff_max = zeros(length(t),1);
u_diff_max = zeros(length(t),1);
v_diff_max = zeros(length(t),1);
w_diff_max = zeros(length(t),1);
for iTime=1:length(t)
    phi = omega*t(iTime)+phi0;
    
    u = U*cos(k*x + phi).*F3D;
    v = -(f0/omega)*U*sin(k*x + phi).*F3D;
    w = k*h(zModeNumber)*U*sin(k*x + phi).*G3D;
    eta = -(k/omega)*h(zModeNumber)*U*cos(k*x + phi).*G3D;
    rho_prime = - drho_dz3D .* eta;
    rho_bar = rho;

    zeta3d = double(squeeze(ncread(file, 'zeta', [1 1 1 iTime], [Inf Inf Inf 1], [1 1 1 1])));
    rho3d = double(squeeze(ncread(file, 'rho', [1 1 1 iTime], [Inf Inf Inf 1], [1 1 1 1])));
    u3d = double(squeeze(ncread(file, 'u', [1 1 1 iTime], [Inf Inf Inf 1], [1 1 1 1])));
    v3d = double(squeeze(ncread(file, 'v', [1 1 1 iTime], [Inf Inf Inf 1], [1 1 1 1])));
    w3d = double(squeeze(ncread(file, 'w', [1 1 1 iTime], [Inf Inf Inf 1], [1 1 1 1])));
    rho_bar_model = double(ncread(file, 'rho_bar'));

    zeta3d = permute(zeta3d, [2 1 3]);
    rho_prime3d = permute(rho3d, [2 1 3]);
    rho_prime3d = (rho_prime3d - repmat(permute(rho_bar_model,[3 2 1]), [Nx Ny 1]));
    u3d = permute(u3d, [2 1 3]);
    v3d = permute(v3d, [2 1 3]);
    w3d = permute(w3d, [2 1 3]);

    
    zeta_diff = (zeta3d-eta)/(max(max(max(eta)))-min(min(min(eta))));
    rho_diff = (rho_prime3d-rho_prime)/(max(max(max(rho_prime)))-min(min(min(rho_prime))));
    u_diff = (u3d-u)/(max(max(max(u)))-min(min(min(u))));
    v_diff = (v3d-v)/(max(max(max(v)))-min(min(min(v))));
    w_diff = (w3d-w)/(max(max(max(w)))-min(min(min(w))));
    
    zeta_diff_max(iTime) = max(max(max(zeta_diff)));
    rho_diff_max(iTime) = max(max(max(rho_diff)));
    u_diff_max(iTime) = max(max(max(u_diff)));
    v_diff_max(iTime) = max(max(max(v_diff)));
    w_diff_max(iTime) = max(max(max(w_diff)));
end

% figure, plot(t, 100*[zeta_diff_max, rho_diff_max, u_diff_max, v_diff_max, w_diff_max])
% xlabel('time (seconds)')
% ylabel('normal error (percent)')
% legend('zeta', 'rho', 'u', 'v', 'w')

figure, plot(t, 100*[u_diff_max, v_diff_max, w_diff_max, rho_diff_max])
xlabel('time (seconds)')
ylabel('normal error (percent)')
legend('u', 'v', 'w', 'rho')

return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%	Figures
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if 1
	zlevel=floor(2*Nz/3);
	figure
	quiver(xDomain,yDomain, squeeze( u(:,:,zlevel) )', squeeze( v(:,:,zlevel) )')
	xlim([min(xDomain) max(xDomain)])
	ylim([min(yDomain) max(yDomain)])
	title(sprintf('Initial vector field (u,v) at depth %f m', zDomain(zlevel)));

	figure
	ylevel=floor(1*Ny/4);
	quiver(xDomain,zDomain, squeeze( u(:,ylevel,:) )', squeeze( w(:,ylevel,:) )',0.8)
	xlim([min(xDomain) max(xDomain)])
	ylim([min(zDomain) max(zDomain)])
	title(sprintf('Initial vector field (u,w) at y=%f m', yDomain(ylevel)));
	
	figure
	pcolor(xDomain,zDomain, squeeze(rho_prime(:,ylevel,:))'), shading flat
	
	figure
	pcolor(xDomain,zDomain, squeeze(eta(:,ylevel,:))'), shading flat
	
end