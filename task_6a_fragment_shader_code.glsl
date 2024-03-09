#version 300 es
#define MAXFLOAT 3.402823466e+38
precision highp float;

// A texture sampling unit, which is bound to the render quad texture buffer
uniform sampler2D textureRendered;

// Texture coordinates coming from the vertex shader, interpolated through the rasterizer
in vec2 fragmentTextureCoordinates;
out vec4 fragColor;
uniform float lightintense;

uniform vec3 lightcolour;
uniform vec4 lightPosition;

in vec3 origin;
in vec3 dir;

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
    vec3 background = 0.4*sphere.colour;
    vec3 diffuselight = 0.4*sphere.colour * lightsource.intensity*max(dot(normal,lightdir),0.0);
    vec3 speclight = 0.15*sphere.colour *lightsource.intensity*pow(max(dot(-reflect,view),0.0),32.0);
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

bool shadowchecker(vec3 point,inout LightSource lightsource,inout Sphere sphere[6],int n){
    
    Ray shadowray;
    shadowray.origin = point;
    shadowray.direction = normalize(lightsource.origin - point);

    for(int j = 0;j<n;j++)
        {
            if (checkintersect(shadowray,sphere[j])[3] == 1.0){return false;}
        }
    for(int j = n+1;j<6;j++)
        {
            if (checkintersect(shadowray,sphere[j])[3] == 1.0){return false;}
        }
    return true;}

bool shadowchecker2(vec3 point,inout LightSource lightsource,inout Sphere sphere[6],int n){
    
    Ray shadowray;
    shadowray.origin = point;
    shadowray.direction = normalize(lightsource.origin - point);
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
                    
                    return planecheck;}
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
                vec3 diffuselight = 0.3*vec3(1.0,1.0,1.0) * lightsource.intensity*max(dot(normal,lightdir),0.0);
                vec3 speclight = 0.9*vec3(1.0,1.0,1.0) *lightsource.intensity*pow(max(dot(-reflect,view),0.0),32.0);
                float dimfactor = (lightsource.intensity/(4.0*pi*len*len));
                if (!shadowchecker2(intersectionpoint, lightsource,sphere,0))
                {planecheck.colour = vec3(0.0,0.0,0.0);}
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
                if (shadowchecker(pos.xyz, lamp1,sphere,i))
                {intersection.colour = (illuminatesphere(pos.xyz, lamp1,sphere[i]));
                }
                else
                {
                intersection.colour = 0.1*sphere[i].colour;
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
float attenuate(float a){
    if (a < 1.0)
    {return 1.0;}
}
// Main program for each fragment of the render quad
void main() {
    //setting the scene
    Sphere sphere[6];
    Plane plane;
    LightSource lamp1;
    lamp1.origin = vec3(lightPosition);
    lamp1.colour = lightcolour;
    lamp1.intensity = lightintense * (1.0+length(lightPosition)); 
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
    intersections[0].colour = vec3(0.0,0.0,0.0);
    intersections[1].colour = vec3(0.0,0.0,0.0);
    intersections[2].colour = vec3(0.0,0.0,0.0);

    Ray primaryray;
    primaryray.origin = origin;
    primaryray.direction = dir;

    int broken = 0;
    for(int m = 0;m < depth;m++)
    {
        intersections[m] = checkall(primaryray,sphere,plane,lamp1);
        if (intersections[m].found == false){
            broken = m;
            break;
        }
        primaryray = createsecondaryray(primaryray,intersections[m]);
    }

    vec3 col;

    if (broken == 1){col = intersections[depth - 3].colour + 0.3*(1.0/length(intersections[depth - 2].origin - intersections[depth - 2].point))*intersections[depth - 3].colour;}
   else{
    float att[2];
    att[0] = (1.0/(1.0 + length(intersections[depth - 1].origin - intersections[depth - 1].point)));
    att[1] = (1.0/(1.0 + length(intersections[depth - 2].origin - intersections[depth - 2].point)));
    col = intersections[depth - 2].colour + 5.0*intersections[depth - 2].colour*att[0]*intersections[depth - 1].colour;
    col = intersections[depth - 3].colour + 5.0*intersections[depth - 3].colour*att[1]*col;
   }
    fragColor = vec4(col,1.0);
}