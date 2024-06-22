// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

#warning Upgrade NOTE: unity_Scale shader variable was removed; replaced 'unity_Scale.w' with '1.0'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/HologramImposter"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

         _NoiseTex("Model Noise Texture", 2D) = "black" {}

        _UsePoint1("_UsePoint1", Int) = 0
        _UsePoint2("_UsePoint2", Int) = 0
        _WidthCount("_WidthCount", Int) = 0
        _HeightCount("_HeightCount", Int) = 0

        //[HDR]_Tint("Tint Color", Color) = (0,.61,.55)
        _Tint("Tint Color", Color) = (0,.61,.55)
        _Opacity("Opacity", Range(0,1)) = 1

        [Toggle] _Axis("Vertical or Horizontal?", Float) = 0
        [Toggle] _LineSpace("Screenspace or object space?", Float) = 0
        _Density("Line Density", Range(0,100)) = 2.61
        _Distortion("model Distortion", Range(0,1)) = 0.02
        _LineSpeed("Line Speed", Range(-100,100)) = 8.91
        _Flicker("Flickering", Range(100,1000)) = 100
        _FlickerStrength("Flicker Strength", Range(1,10)) = 2.7

        //secondary lines
        _Brightness("Brightness", Range(1, 10)) = 9.15
        _Density2("Secondary flicker Density", Range(0,100)) = 7
        _Quantize("Secondary flicker smoothness ", Range(1,100)) = 2
        _LineSpeed2("Secondary flicker Speed", Range(-10,10)) = 3.7
        _Brightness2("secondary flicker brightness", Range(1, 10)) = 4.55

        //_ImposterFrames("Sprite atlas dimensions",  float) = 8
        //_ImposterSize("Radius", float) = 1
        //_ImposterOffset("Offset", Vector) = (0,0,0,0)

    }
        CGINCLUDE //shared includes, variables, and functions
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

        sampler2D _MainTex;
        float4 _MainTex_ST;
        fixed4 _Tint;

        sampler2D _NoiseTex;

        int _WidthCount;
        int _HeightCount;

        float _Axis, _LineSpace, _Opacity;
        half _Density, _Density2, _Distortion, _LineSpeed, _LineSpeed2, _Flicker, _FlickerStrength, _Brightness, _Brightness2, _RimSize, _RimBrightness;
        int _Quantize;

        half3 _ImposterOffset;
        half _ImposterFrames;

        float _UsePoint1;
        float _UsePoint2;

        float kEpsilonNormalSqrt = 1e-15F;
        float rad2deg = 9.54929658551;
        float epsilon = 0.00000001;

        //float rayPlaneIntersection(float3 rayDir, float3 rayPos, float3 planeNormal, float3 planePos)
        //{
        //    float denom = dot(planeNormal, rayDir);
        //    denom = max(denom, 0.000001); // avoid divide by zero
        //    float3 diff = planePos - rayPos;
        //    return dot(diff, planeNormal) / denom;
        //}

        float angleBetween(fixed3 vec1, fixed3 vec2) 
        {
            return acos(dot(vec1, vec2) / (length(vec1) * length(vec2)));
        }
        float Quantize(float num, float quantize)
        {
            return round(num * quantize) / quantize;
        }




        //half2 VecToSphereOct(half3 vec)
        //{
        //    vec.xz /= dot(1, abs(vec));
        //    if (vec.y <= 0)
        //    {
        //        half2 flip = vec.xz >= 0 ? half2(1, 1) : half2(-1, -1);
        //        vec.xz = (1 - abs(vec.zx)) * flip;
        //    }
        //    return vec.xz;
        //}

        //half2 VectorToGrid(half3 vec)
        //{
        //    half2 coord;

        //    //if (_ImposterFullSphere)
        //    //{
        //    //    coord = VecToSphereOct(vec);
        //    //}
        //    //else
        //    //{
        //    //    vec.y = max(0.001, vec.y);
        //    //    vec = normalize(vec);
        //    //    coord = VecToHemiOct(vec);
        //    //} 

        //    coord = VecToSphereOct(vec);

        //    return coord;
        //}

        //half3 OctaSphereEnc(half2 coord)
        //{
        //    half3 vec = half3(coord.x, 1 - dot(1, abs(coord)), coord.y);
        //    if (vec.y < 0)
        //    {
        //        half2 flip = vec.xz >= 0 ? half2(1, 1) : half2(-1, -1);
        //        vec.xz = (1 - abs(vec.zx)) * flip;
        //    }
        //    return vec;
        //}

        //half3 GridToVector(half2 coord)
        //{
        //    half3 vec;
        //    //if (_ImposterFullSphere)
        //    //{
        //    //    vec = OctaSphereEnc(coord);
        //    //}
        //    //else
        //    //{
        //    //    vec = OctaHemiEnc(coord);
        //    //}

        //    vec = OctaSphereEnc(coord);

        //    return vec;
        //}

        ////frame and framecout, returns 
        //half3 FrameXYToRay(half2 frame, half2 frameCountMinusOne)
        //{
        //    //divide frame x y by framecount minus one to get 0-1
        //    half2 f = frame.xy / frameCountMinusOne;
        //    //bias and scale to -1 to 1
        //    f = (f - 0.5) * 2.0;
        //    //convert to vector, either full sphere or hemi sphere
        //    half3 vec = GridToVector(f);
        //    vec = normalize(vec);
        //    return vec;
        //}

        //half3 ITBasis(half3 vec, half3 basedX, half3 basedY, half3 basedZ)
        //{
        //    return half3(dot(basedX, vec), dot(basedY, vec), dot(basedZ, vec));
        //}

        //half3 FrameTransform(half3 projRay, half3 frameRay, out half3 worldX, out half3 worldZ)
        //{
        //    //TODO something might be wrong here
        //    worldX = normalize(half3(-frameRay.z, 0, frameRay.x));
        //    worldZ = normalize(cross(worldX, frameRay));

        //    projRay *= -1.0;

        //    half3 local = normalize(ITBasis(projRay, worldX, frameRay, worldZ));
        //    return local;
        //}

        //half3 SpriteProjection(half3 pivotToCameraRayLocal, half frames, half2 size, half2 coord)
        //{
        //    half3 gridVec = pivotToCameraRayLocal;

        //    //octahedron vector, pivot to camera
        //    half3 y = normalize(gridVec);

        //    half3 x = normalize(cross(y, half3(0.0, 1.0, 0.0)));
        //    half3 z = normalize(cross(x, y));

        //    half2 uv = ((coord * frames) - 0.5) * 2.0; //-1 to 1 

        //    half3 newX = x * uv.x;
        //    half3 newZ = z * uv.y;

        //    half2 halfSize = size * 0.5;

        //    newX *= halfSize.x;
        //    newZ *= halfSize.y;

        //    half3 res = newX + newZ;

        //    return res;
        //}

        float sqrMagnitude(float3 input)
        {
            return input.x * input.x + input.y * input.y + input.z * input.z;
        }

        float Angle(float3 from, float3 to)
        {
            // sqrt(a) * sqrt(b) = sqrt(a * b) -- valid for real numbers
            float denominator = sqrt(sqrMagnitude(from) * sqrMagnitude(to));
            if (denominator < kEpsilonNormalSqrt)
            {
                return 0;
            }

            float dotted = clamp(dot(from, to) / denominator, -1, 1);
            //return (acos(dotted)) * rad2deg;
            return degrees(acos(dotted));
        }

        float SignedAngle(float3 from, float3 to, float3 axis)
        {
            float unsignedAngle = Angle(from, to);

            float cross_x = from.y * to.z - from.z * to.y;
            float cross_y = from.z * to.x - from.x * to.z;
            float cross_z = from.x * to.y - from.y * to.x;
            float signNum = sign(axis.x * cross_x + axis.y * cross_y + axis.z * cross_z);
            return unsignedAngle * signNum;
        }

        float3 ProjectOnPlane(float3 vector1, float3 planeNormal)
        {
            float sqrMag = dot(planeNormal, planeNormal);
            if (sqrMag < epsilon)
                return vector1;
            else
            {
                float dotted = dot(vector1, planeNormal);
                return float3(vector1.x - planeNormal.x * dotted / sqrMag, vector1.y - planeNormal.y * dotted / sqrMag, vector1.z - planeNormal.z * dotted / sqrMag);
            }
        }

        struct appdata
        {
            float4 vertex : POSITION;
            float4 texcoord : TEXCOORD0;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
        };
        struct v2f
        {
            float4 pos : SV_POSITION;
            float4 posObj: TEXCOORD0;
            float4 posWorld : TEXCOORD1;
            // position of the vertex (and fragment) in world space 
            float4 tex : TEXCOORD2;
            fixed3 vLight : COLOR;
        };


        v2f vert(appdata input)
        {
            v2f output;
            //output.pos = UnityObjectToClipPos(input.vertex);
            //// billboard mesh towards camera
            //float3 vpos = mul((float3x3)unity_ObjectToWorld, input.vertex.xyz);
            //float4 worldCoord = float4(unity_ObjectToWorld._m03, unity_ObjectToWorld._m13, unity_ObjectToWorld._m23, 1);
            //float4 viewPos = mul(UNITY_MATRIX_V, worldCoord) + float4(vpos, 0);
            //// calculate distance to vertical billboard plane seen at this vertex's screen position

            //output.pos = mul(UNITY_MATRIX_P, viewPos);


                            // center camera position
#ifdef UNITY_SINGLE_PASS_STEREO
            float3 camPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
#else
            float3 camPos = _WorldSpaceCameraPos;
#endif

            // world space mesh pivot
            float3 worldPivot = unity_ObjectToWorld._m03_m13_m23;

            // x & y axis scales only
            float3 scale = float3(
                length(unity_ObjectToWorld._m00_m01_m02),
                length(unity_ObjectToWorld._m10_m11_m12),
                1.0
                );

            // calculate billboard rotation matrix
            float3 f = normalize(lerp(
                -UNITY_MATRIX_V[2].xyz, // view forward dir
                normalize(worldPivot - camPos), // camera to pivot dir
                1));
            float3 u = float3(0.0, 1.0, 0.0);
            float3 r = normalize(cross(u, f));
            u = -normalize(cross(r, f));
            float3x3 billboardRotation = float3x3(r, u, f);

            // apply scale, rotation, and translation to billboard
            float3 worldPos = mul(input.vertex.xyz * scale, billboardRotation) + worldPivot;

            // transform into clip space
            output.pos = UnityWorldToClipPos(worldPos);

            output.tex = input.texcoord;
            //output.worldPos = mul(unity_ObjectToWorld, input.vertex);
            output.posWorld = mul(UNITY_MATRIX_M, input.vertex);

            output.posObj = input.vertex;

            return output;
        }

        fixed4 frag(v2f input) : SV_Target
        {


            float2 cameraWidthRange = float2(0, 360);
            float2 cameraHeightRange = float2(0, 180);
            float divideAreaX = 8;
            float2 divideDuration = float2(45, 25.7);


            //float3 tranformForward = normalize(mul(float3(0, 0, 1), UNITY_MATRIX_I_V));//not 0,0,0
            //float3 tranformRight = normalize(mul(float3(1, 0, 0), UNITY_MATRIX_I_V));//not 0,0,0

            //float3 cameraVecForUp = ProjectOnPlane(-tranformForward, float3(0, 1, 0));
            //float3 rightForUp = ProjectOnPlane(float3(1, 0, 0), float3(0, 1, 0));

            //float angleX = 180 + (SignedAngle(cameraVecForUp, rightForUp, float3(0, 1, 0)) + 360) % 360;

            //float3 cameraVecForForward = ProjectOnPlane(tranformForward, tranformRight);
            //float3 forwardForRight = ProjectOnPlane(float3(0, -1, 0), tranformRight);

            //float angleY = Angle(cameraVecForForward, forwardForRight);
            //angleY = 67;

            //float3 cameraToModel = input.posWorld.xyz - _WorldSpaceCameraPos.xyz;
            float4 origin = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));

            //float3 cameraToModel = float3(0,0,0).xyz - _WorldSpaceCameraPos.xyz;
            float3 cameraToModel = origin.xyz - _WorldSpaceCameraPos.xyz;

            // Normalize the direction vector
            float3 normalizedDirection = normalize(cameraToModel);

            // Calculate the X angle (pitch) and Y angle (yaw) from the normalized direction vector
            float angleY = 90 + degrees(asin(normalizedDirection.y) );
            float angleX = 90 + degrees(atan2(normalizedDirection.x, -normalizedDirection.z));




            float2 usePoint = float2(1, 4);

            //usePoint.x = int(8 *(xAngle - cameraHeightRange.x + divideDuration.x * .5) / divideDuration.x);
            //usePoint.y = int(8*(yAngle - cameraHeightRange.x + divideDuration.y * .5) / divideDuration.y);  
            usePoint.x = int((angleX + divideDuration.x * 0.5f + 360) % 360 / divideDuration.x);
            usePoint.y = int((angleY - cameraHeightRange.x + divideDuration.y * 0.5f) / divideDuration.y);



            //quick return to show xAngle and yAngle
            //return float4(xAngle* 1, yAngle * 1, 0, 1);

            //usePoint.x = int(8*((yawCameraCorrected - cameraHeightRange.x + divideDuration.x * .5) / divideDuration.x));

            //usePoint.y = 8*((yawCameraCorrected - cameraHeightRange.x + divideDuration.y * .5) / divideDuration.y);
            //return float4(usePoint.x, usePoint.y, 0, 1);
            //return float4(yawCameraCorrected, 1, 1, 1);

            //dimensions of the imposter sprite grid
            float2 uvSize = float2(_WidthCount, _HeightCount);
            float2 uvStartPoint = float2(usePoint.x / _WidthCount, usePoint.y / _HeightCount);
            //float2 uvStartPoint = float2(_UsePoint1 / _WidthCount, _UsePoint2 / _HeightCount);

            float adjustment = _Distortion * (0.5 - tex2D(_NoiseTex, float2(input.tex.xy + _Time.y)));

            fixed4 col = tex2D(_MainTex, uvStartPoint + (input.tex / uvSize) + adjustment);
            col.rgb = clamp(col.rgb * 0.5 + 0.5 * col.rgb * 3.2, 0.0, 1.0);
            col.rgb *= _Tint.rgb;

            float PrimaryPos = 0;
            if (_LineSpace == 0)
            {
                PrimaryPos = input.pos[_Axis];
            }
            else
            {
                PrimaryPos = input.tex[_Axis];;
                _Density *= 50;
            }

            //col.rgb *= 0.9 + 0.1 * sin(_LineSpeed * _Time.y + PrimaryPos.x * _Density);
            col.rgb *= 0.9 + 0.1 * sin(_LineSpeed * _Time.y + PrimaryPos * _Density);

            col.a = col.a * (0.9 + 0.1 * sin(_LineSpeed * _Time.y + ((PrimaryPos) * _Density))) > 0.9 ? 1 : 0;
            col.a = _Density == 0 ? 1 : col.a;

            col.rgb *= 0.9 + 0.1 * _Brightness2 * round(sin(_LineSpeed2 * _Time.y + input.posWorld.y * _Density2) * _Quantize) / _Quantize;
            // Flicker
            col.rgb *= 0.97 + 0.03 * _FlickerStrength * sin(_Flicker * _Time.y);
            col.rgb *= _Brightness;

            clip(col.a - 0.01);
            return col;
        }

    ENDCG
    SubShader
    {
        Tags{ "RenderType" = "Transparent" }
            LOD 100
            Cull Off


        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            ENDCG
        }
    }
}
