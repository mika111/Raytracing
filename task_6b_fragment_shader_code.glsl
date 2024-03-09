#version 300 es
#define MAXFLOAT 3.402823466e+38
precision highp float;

/*here I have added fog and soft shadows
 
To add soft shadows I have extended the existing shadow checker to shoot shadow rays whose direction vector has been modified 
by a small pseudo random number.The random number is generated using a custom function that takes in the rasterized vertex coords
and passes them into a sin and cos function before dotting them with some random numbers to form a vector of random numbers. 
This is then multiplied by the uniform shadowvar (stands for shadow variance) which lets the user control how wide the sampling 
domain for the pseudo random vector is. These shadow rays are then calculated as normal (if there is a hit then color = 0 
else do Phong lighting) and averaged. There are 4 of these shadow rays per occluded pixel.

To add fog i first set any pixel whose ray does not hit anything to white (as in essence all you can see is fog)
and then attenuated the intensity of the colour values calculated by an exponential function (with ray distance in the exponent) and added to it pure 
white attenuated by a positive exponential function. These exponentials contain a uniform float as part of their exponent called fogthickness.
This can be adjusted to simulate various fog thicknesses.
*/

// A texture sampling unit, which is bound to the render quad texture buffer
uniform sampler2D textureRendered;

// Texture coordinates coming from the vertex shader, interpolated through the rasterizer
in vec2 fragmentTextureCoordinates;
out vec4 fragColor;
uniform float lightintense;
uniform vec3 lightposition;
uniform vec3 lightcolour;
uniform float fogthickness;
uniform float shadowvar;
in vec3 origin;
in vec3 dir;
in vec3 vertexP;


// Model matrix
uniform mat4 mMatrix;
// View matrix
uniform mat4 vMatrix;
// Projection matrix
uniform mat4 pMatrix;

struct LightSource
{
vec3 origin;
vec3 colour;
float intensity;
};

struct Ray {
vec3 origin;
vec3 direction;
};

struct Sphere {
float radius;
vec3 centre;
vec3 colour;
};

struct Plane {
vec3 point;
vec3 normal;
vec3 colour;
};

struct Intersection {
vec3 point;
vec3 normal;
vec3 colour;
vec3 origin;
bool found;
bool occluded;
};

struct Planecheck {
vec3 point;
vec3 normal;
vec3 colour;
bool parallel;
};

vec3 illuminatesphere(vec3 point,inout LightSource lightsource,inout Sphere sphere) {
    float pi = 3.14;
    float len = length(lightsource.origin - point);
    vec3 normal = normalize(point - sphere.centre);
    vec3 lightdir = normalize(lightsource.origin - point);
    vec3 view = normalize(point - origin);
    vec3 reflect = normalize(2.0*max(dot(normal,lightdir),0.0)*normal - lightdir);
    vec3 background = 0.1*sphere.colour;
    vec3 diffuselight = 0.3*sphere.colour * lightsource.intensity*max(dot(normal,lightdir),0.0);
    vec3 speclight = 0.25*sphere.colour *lightsource.intensity*pow(max(dot(-reflect,view),0.0),32.0);
    float dimfactor = (lightsource.intensity/(4.0*pi*len*len));
    return dimfactor*(background + speclight + diffuselight);
}

vec4 checkintersect(inout Ray ray,inout Sphere sphere){
    
    vec3 distancevec;
    vec3 deltap = ray.origin - sphere.centre;
    float discriminant = pow(dot(normalize(ray.direction),deltap),2.0) - pow(length(deltap),2.0) + pow(sphere.radius,2.0);

    if (discriminant >= 0.0)
    {
        float mu1 = -dot(deltap,normalize(ray.direction)) - sqrt(discriminant);
        float mu2 = -dot(deltap,normalize(ray.direction)) + sqrt(discriminant);
        if (min(mu1,mu2) <0.0){return vec4(0.0,0.0,0.0,0.0);}
        return vec4(min(mu1,mu2) * normalize(ray.direction) + ray.origin,1.0);
    }
    
    return vec4(0.0,0.0,0.0,0.0);
}

bool shadowchecker(vec3 point,inout LightSource lightsource,inout Sphere sphere[6],int n, vec3 buffer){
    
    Ray shadowray;
    shadowray.origin = point;
    shadowray.direction = normalize(lightsource.origin - point) + buffer;

    for(int j = 0;j<n;j++)
        {
            if (checkintersect(shadowray,sphere[j])[3] == 1.0){return false;}
        }
    for(int j = n+1;j<6;j++)
        {
            if (checkintersect(shadowray,sphere[j])[3] == 1.0){return false;}
        }
    return true;}
vec3 random(vec3 seed){
    return shadowvar*fract(vec3(0.5 + cos(dot(seed,vec3(21.4,31.7,51.4))) + sin(dot(seed,vec3(21.1,12.7,20.4)))));
}


bool shadowchecker2(vec3 point,inout LightSource lightsource,inout Sphere sphere[6],int n,vec3 buffer){
    
    Ray shadowray;
    shadowray.origin = point;
    shadowray.direction = normalize(lightsource.origin - point) + buffer;
    for(int j = 0;j<6;j++)
        {
            if (checkintersect(shadowray,sphere[j])[3] == 1.0){return false;}
        }
    return true;}

Planecheck checkplane(inout Ray ray,inout Plane plane,inout LightSource lightsource,inout Sphere sphere[6])
    {
        Planecheck planecheck;
        planecheck.parallel = true;
        planecheck.point= vec3(0.0,0.0,0.0);
        planecheck.normal = vec3(0.0,0.0,0.0);
        planecheck.colour = vec3(0.0,0.0,0.0);
        if (dot(plane.normal,ray.direction) != 0.0)
        {
            
            float dist = dot(plane.point - ray.origin,plane.normal)/dot(ray.direction,plane.normal);
            vec3 intersectionpoint = ray.origin + dist*ray.direction;
            if (dist < 0.0)
                {
                    
                    return planecheck;
                    }
            planecheck.point = intersectionpoint;
            planecheck.normal = plane.normal;

        planecheck.parallel = false;
        //check checkerboard
            vec3 v1 = normalize(plane.point - dot(plane.point,plane.normal));
            vec3 v2 = normalize(cross(v1,plane.normal));
            float d1 = floor(dot(intersectionpoint - plane.point, 4.0*v1));
            float d2 = floor(dot(intersectionpoint - plane.point, 4.0*v2));
        
        if ((mod(abs(d1-d2),2.0) == 1.0) && dist>0.0){
                float pi = 3.14;
                float len = length(lightsource.origin - intersectionpoint);
                vec3 normal = normalize(plane.normal);
                vec3 lightdir = normalize(lightsource.origin - intersectionpoint);
                vec3 view = normalize(intersectionpoint - origin);
                vec3 reflect = normalize(2.0*max(dot(normal,lightdir),0.0)*normal - lightdir);
                vec3 background = 0.2*vec3(1.0,1.0,1.0);
                vec3 diffuselight = 0.4*vec3(1.0,1.0,1.0) * lightsource.intensity*max(dot(normal,lightdir),0.0);
                vec3 speclight = 0.9*vec3(1.0,1.0,1.0) *lightsource.intensity*pow(max(dot(-reflect,view),0.0),32.0);
                float dimfactor = (lightsource.intensity/(4.0*pi*len*len));
                if (!shadowchecker2(intersectionpoint, lightsource,sphere,0,vec3(0.0,0.0,0.0)))
                {
                vec3 rand = random(vertexP);
                int num = 1;
                for (int z = 0;z<3; z++){
                    if ((shadowchecker2(intersectionpoint, lightsource,sphere,0,rand[z]*vec3(0.0,0.0,0.0))))
                    {planecheck.colour += dimfactor*(background + speclight + diffuselight);
                    num ++;}
                }
                planecheck.colour = planecheck.colour/float(num);}
                else
                {planecheck.colour = dimfactor*(background + speclight + diffuselight);}
        }else{
            planecheck.colour = vec3(0.2,0.2,0.2);
        }
    }
        return planecheck;
    }

Ray createsecondaryray(inout Ray primaryray,inout Intersection intersection)
{
    primaryray.origin = 0.001 *normalize(intersection.normal) + intersection.point;
    primaryray.direction = primaryray.direction - (dot(2.0*primaryray.direction,intersection.normal))*intersection.normal;
    return primaryray;
}

Intersection checkall(Ray primaryray,inout Sphere sphere[6],inout Plane plane,inout LightSource lamp1)

{
    float mindistance = MAXFLOAT;
    Intersection intersection;
    intersection.found = true;
    Planecheck planeinfo = checkplane(primaryray,plane,lamp1,sphere);
    intersection.colour = planeinfo.colour;
    intersection.normal = planeinfo.normal;
    intersection.point = planeinfo.point;
    intersection.origin = primaryray.origin;
    mindistance = length(intersection.point - primaryray.origin);
    if (planeinfo.parallel == true){
        intersection.found = false;
        mindistance = MAXFLOAT;
    }
        for(int i = 0;i < 6;i++)
    {
        vec4 pos = checkintersect(primaryray,sphere[i]);
        if (pos[3] == 1.0)
        {
            float distance = length(primaryray.origin - pos.xyz);
            if (distance<=mindistance)
            {
                if (shadowchecker(pos.xyz, lamp1,sphere,i,vec3(0.0,0.0,0.0)))
                {intersection.colour = (illuminatesphere(pos.xyz, lamp1,sphere[i]));
                }
                else
                {
                vec3 colour = vec3(0.0,0.0,0.0);
                vec3 rand = random(vertexP);
                int num = 1;
                for (int z = 0;z<3; z++){
                    if ((shadowchecker(pos.xyz, lamp1,sphere,i,rand[z]*vec3(0.0,0.0,0.0))))
                        {intersection.colour += (illuminatesphere(pos.xyz, lamp1,sphere[i]));
                        num ++;}
                }
                intersection.colour = intersection.colour/float(num);
                intersection.occluded = true;
                }
                mindistance = distance;
                intersection.point = pos.xyz;
                intersection.origin = primaryray.origin;
                intersection.normal = normalize(sphere[i].centre - pos.xyz);
                intersection.found = true;
            }
        }
    }    
    return intersection;
}

// Main program for each fragment of the render quad
void main() {
    //setting the scene
    Sphere sphere[6];
    Plane plane;
    LightSource lamp1;
    lamp1.origin = lightposition;
    lamp1.colour = lightcolour;
    lamp1.intensity = lightintense; 
    sphere[0].centre = vec3(-2.0, 1.5, -3.5);
    sphere[0].radius = 1.5;
    sphere[0].colour = vec3(0.8,0.8,0.8);
    sphere[1].centre = vec3(-0.5, 0.0, -2.0);
    sphere[1].radius = 0.6;
    sphere[1].colour = vec3(0.3,0.8,0.3);
    sphere[2].centre = vec3(1.0, 0.7, -2.2);
    sphere[2].radius = 0.8;
    sphere[2].colour = vec3(0.3,0.8,0.8);
    sphere[3].centre = vec3(0.7, -0.3, -1.2);
    sphere[3].radius = 0.2;
    sphere[3].colour = vec3(0.8,0.8,0.3);
    sphere[4].centre = vec3(-0.7, -0.3, -1.2);
    sphere[4].radius = 0.2;
    sphere[4].colour = vec3(0.8,0.3,0.3);
    sphere[5].centre = vec3(0.2, -0.2, -1.2);
    sphere[5].radius = 0.3;
    sphere[5].colour = vec3(0.8,0.3,0.8);
    plane.point = vec3(0,-0.5, 0);
    plane.normal = vec3(0, 1.0, 0);
    plane.colour = vec3(1, 1, 1);

    const int depth = 3;
    Intersection intersections[depth];
    Ray primaryray;
    primaryray.origin = origin;
    primaryray.direction = dir;


    for(int l = 0;l < depth;l++)
    {
        intersections[l] = checkall(primaryray,sphere,plane,lamp1);
        if (intersections[l].found == false){
            break;
        }
        primaryray = createsecondaryray(primaryray,intersections[l]);
    }

    vec3 col;
    col = intersections[depth - 2].colour + 0.7*exp(-fogthickness*2.0 * length(intersections[depth-1].origin - intersections[depth-1].point))*intersections[depth - 1].colour;
    col += intersections[depth - 3].colour + 0.7*exp(-fogthickness*2.0 * length(intersections[depth-2].origin - intersections[depth-2].point))*col;

    col = 0.75*col*exp(-fogthickness*2.0 * length(intersections[0].origin - intersections[0].point));
    col = col*1.0/(fogthickness*2.0 * length(intersections[0].origin - intersections[0].point));
    if (intersections[0].found == false){
        fragColor = vec4(1.0,1.0,1.0,0.8);
    }else{
    fragColor = vec4((col + 0.3*vec3(1.0,1.0,1.0)*pow(length(intersections[0].origin - intersections[0].point),1.0)*fogthickness),0.8); 
    }}