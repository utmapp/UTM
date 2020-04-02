/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and C/ObjC source
*/

#ifndef UTMShaderTypes_h
#define UTMShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum UTMVertexInputIndex
{
    UTMVertexInputIndexVertices     = 0,
    UTMVertexInputIndexViewportSize = 1,
    UTMVertexInputIndexTransform    = 2,
    UTMVertexInputIndexHasAlpha     = 3,
} UTMVertexInputIndex;

// Texture index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API texture set calls
typedef enum UTMTextureIndex
{
    UTMTextureIndexBaseColor = 0,
} UTMTextureIndex;

//  This structure defines the layout of each vertex in the array of vertices set as an input to our
//    Metal vertex shader.  Since this header is shared between our .metal shader and C code,
//    we can be sure that the layout of the vertex array in the code matches the layout that
//    our vertex shader expects
typedef struct
{
    // Positions in pixel space (i.e. a value of 100 indicates 100 pixels from the origin/center)
    vector_float2 position;

    // 2D texture coordinate
    vector_float2 textureCoordinate;
} UTMVertex;

#endif /* UTMShaderTypes_h */
