/*
MIT License

Copyright (c) 2025 Dice

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#ifndef MAT_H
#define MAT_H

#define MAT_VERSION 11

#define MAT_ATTRIBUTE_META 0x00
#define MAT_ATTRIBUTE_MESH 0x10
#define MAT_ATTRIBUTE_VERT 0x22
#define MAT_ATTRIBUTE_NORM 0x32
#define MAT_ATTRIBUTE_TINT 0x42
#define MAT_ATTRIBUTE_TEXT 0x51
#define MAT_ATTRIBUTE_SKIN 0x60
#define MAT_ATTRIBUTE_ANIM 0x70
#define MAT_ATTRIBUTE_POSE 0x8B
#define MAT_ATTRIBUTE_SLOT 0x90
#define MAT_ATTRIBUTE_TIME 0xA0

// INTERFACE

typedef struct {
	void           *user;
	unsigned char (*read)(void *user);
	void          (*seek)(void *user,unsigned int unit);
	unsigned int  (*head)(void *user);
	unsigned int  (*size)(void *user);
} mat_interface;

// MESH

typedef struct {
	char         *name_data;
	float        *vert_data;
	float        *norm_data;
	float        *tint_data;
	float        *text_data;
	unsigned int *skin_data;
	unsigned int  name_size;
	unsigned int  vert_size;
	unsigned int  norm_size;
	unsigned int  tint_size;
	unsigned int  text_size;
	unsigned int  skin_size;
} mat_mesh;

mat_mesh* mat_mesh_load(
	mat_interface interface,
	unsigned int  id
);

mat_mesh* mat_mesh_load_file(
	char        *filename,
	unsigned int id
);

void mat_mesh_free(
	mat_mesh *mesh
);

// ANIMATION

typedef struct {
	char         *name_data;
	float        *pose_data;
	float        *time_data;
	unsigned int *slot_data;
	unsigned int  name_size;
	unsigned int  pose_size;
	unsigned int  slot_size;
	unsigned int  time_size;
} mat_animation;

mat_animation* mat_animation_load(
	mat_interface interface,
	unsigned int  id
);

mat_animation* mat_animation_load_file(
	char        *filename,
	unsigned int id
);

void mat_animation_free(
	mat_animation *animation
);

void mat_animation_pose(
	mat_animation *animation,
	float          time,
	unsigned int   bone,
	float          pose[16]
);

#endif

/************************[IMPLEMENTATION BEGINS HERE]*************************/

#ifdef MAT_IMPLEMENTATION

#include <stdio.h>
#include <math.h>
#include <float.h>
#include <malloc.h>

#define MAT_MIN(A,B) ((A)<(B)?(A):(B))
#define MAT_MAX(A,B) ((A)>(B)?(A):(B))

// FILE INTERFACE

unsigned char __mat_file_read(
	void *user
) {
	return (unsigned char)fgetc((FILE*)user);
}

void __mat_file_seek(
	void        *user,
	unsigned int unit
) {
	fseek(
		(FILE*)user,
		(long)unit,
		SEEK_SET
	);
}

unsigned int __mat_file_head(
	void *user
) {
	return (unsigned int)ftell((FILE*)user);
}

unsigned int __mat_file_size(
	void *user
) {
	FILE *file = (FILE*)user;
	long head  = ftell(file);

	fseek(file,0,SEEK_END);
	long size=ftell(file);
	fseek(file,head,SEEK_SET);

	return (unsigned int)size;
}

// DECODING FUNCTIONS

static unsigned int mat_decode_uint(
	mat_interface interface
) {
	return (
		(unsigned int)interface.read(interface.user)<<24|
		(unsigned int)interface.read(interface.user)<<16|
		(unsigned int)interface.read(interface.user)<<8|
		(unsigned int)interface.read(interface.user)
	);
}

static float mat_decode_fixed(
	mat_interface interface,
	unsigned int  integer,
	unsigned int  fraction
) {
	if (integer==0 && fraction==0) {
		return (float)interface.read(interface.user);
	}

	unsigned long encoded = 0;
	double        decoded;

	for (unsigned int i=0; i<integer+fraction; i++) {
		encoded=(encoded<<8)|interface.read(interface.user);
	}

	decoded = (double)encoded;
	decoded = decoded/(1<<(fraction*8));
	decoded = decoded-(1<<(integer*8))/2;

	return (float)decoded;
}

void mat_decode(
	mat_interface interface,
	unsigned int  id,
	unsigned int  attribute,
	unsigned int *size,
	void        **data
) {
	*data = NULL;
	*size = 0;

	interface.seek(interface.user,0);

	unsigned int mat_size = interface.size(interface.user);

	while (interface.head(interface.user)<mat_size) {
		unsigned int attribute_id     = mat_decode_uint(interface);
		unsigned int attribute_type   = interface.read(interface.user);
		unsigned int attribute_format = interface.read(interface.user);
		unsigned int attribute_count  = mat_decode_uint(interface);

		if (
			attribute_id==id &&
			attribute_type==attribute
		) {
			switch(attribute) {
				case MAT_ATTRIBUTE_META:
					*data=calloc(
						attribute_count,
						sizeof(unsigned char)
					);
					break;
				case MAT_ATTRIBUTE_MESH:
				case MAT_ATTRIBUTE_ANIM:
					*data=calloc(
						attribute_count+1,
						sizeof(char)
					);
					break;
				case MAT_ATTRIBUTE_SKIN:
				case MAT_ATTRIBUTE_SLOT:
					*data=calloc(
						attribute_count,
						sizeof(unsigned int)
					);
					break;
				default:
					*data=calloc(
						attribute_count,
						sizeof(float)
					);
			}

			if (*data==NULL) return;

			*size=attribute_count;

			for (unsigned int i=0; i<attribute_count; i++) {
				float value=mat_decode_fixed(
					interface,
					attribute_format>>4,
					attribute_format&0x0F
				);

				switch(attribute) {
					case MAT_ATTRIBUTE_META:
						((unsigned char*)(*data))[i]=(unsigned char)value;
						break;
					case MAT_ATTRIBUTE_MESH:
					case MAT_ATTRIBUTE_ANIM:
						((char*)(*data))[i]=(char)value;
						break;
					case MAT_ATTRIBUTE_SKIN:
					case MAT_ATTRIBUTE_SLOT:
						((unsigned int*)(*data))[i]=(unsigned int)value;
						break;
					default:
						((float*)(*data))[i]=value;
				}
			}

			return;
		}

		if (attribute_format==0) {
			interface.seek(
				interface.user,
				interface.head(interface.user)
				+attribute_count
			);
		} else {
			interface.seek(
				interface.user,
				interface.head(interface.user)
				+attribute_count
				*((attribute_format>>4)+(attribute_format&0x0F))
			);
		}
	}
}

// MESH FUNCTIONS

mat_mesh* mat_mesh_load(
	mat_interface interface,
	unsigned int  id
) {
	mat_mesh *mesh=malloc(sizeof(mat_mesh));

	if (mesh==NULL) return NULL;

	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_MESH,
		&mesh->name_size,
		(void**)&mesh->name_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_VERT,
		&mesh->vert_size,
		(void**)&mesh->vert_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_NORM,
		&mesh->norm_size,
		(void**)&mesh->norm_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_TINT,
		&mesh->tint_size,
		(void**)&mesh->tint_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_TEXT,
		&mesh->text_size,
		(void**)&mesh->text_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_SKIN,
		&mesh->skin_size,
		(void**)&mesh->skin_data
	);

	return mesh;
}

mat_mesh* mat_mesh_load_file(
	char        *filename,
	unsigned int id
) {
	FILE *mat_file=fopen(filename,"rb");

	if (mat_file==NULL) return NULL;

	mat_mesh *mesh=mat_mesh_load(
		(mat_interface){
			(void*)mat_file,
			__mat_file_read,
			__mat_file_seek,
			__mat_file_head,
			__mat_file_size
		},
		id
	);

	fclose(mat_file);

	return mesh;
}

void mat_mesh_free(
	mat_mesh *mesh
) {
	if (mesh==NULL) return;

	if (mesh->name_data!=NULL) free(mesh->name_data);
	if (mesh->vert_data!=NULL) free(mesh->vert_data);
	if (mesh->norm_data!=NULL) free(mesh->norm_data);
	if (mesh->tint_data!=NULL) free(mesh->tint_data);
	if (mesh->text_data!=NULL) free(mesh->text_data);
	if (mesh->skin_data!=NULL) free(mesh->skin_data);

	free(mesh);
}

// ANIMATION FUNCTIONS

mat_animation* mat_animation_load(
	mat_interface interface,
	unsigned int  id
) {
	mat_animation *animation=malloc(sizeof(mat_animation));

	if (animation==NULL) return NULL;

	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_ANIM,
		&animation->name_size,
		(void**)&animation->name_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_POSE,
		&animation->pose_size,
		(void**)&animation->pose_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_SLOT,
		&animation->slot_size,
		(void**)&animation->slot_data
	);
	mat_decode(
		interface,
		id,
		MAT_ATTRIBUTE_TIME,
		&animation->time_size,
		(void**)&animation->time_data
	);

	return animation;
}

mat_animation* mat_animation_load_file(
	char        *filename,
	unsigned int id
) {
	FILE *mat_file=fopen(filename,"rb");

	if (mat_file==NULL) return NULL;

	mat_animation *animation=mat_animation_load(
		(mat_interface){
			(void*)mat_file,
			__mat_file_read,
			__mat_file_seek,
			__mat_file_head,
			__mat_file_size
		},
		id
	);

	fclose(mat_file);

	return animation;
}

void mat_animation_free(
	mat_animation *animation
) {
	if (animation==NULL) return;

	if (animation->name_data!=NULL) free(animation->name_data);
	if (animation->pose_data!=NULL) free(animation->pose_data);
	if (animation->slot_data!=NULL) free(animation->slot_data);
	if (animation->time_data!=NULL) free(animation->time_data);

	free(animation);
}

void mat_animation_pose(
	mat_animation *animation,
	float          time,
	unsigned int   bone,
	float          pose[16]
) {
	if (animation==NULL) return;

	float        *pose_data = animation->pose_data;
	float        *time_data = animation->time_data;
	unsigned int *slot_data = animation->slot_data;
	unsigned int  pose_size = animation->pose_size;
	unsigned int  time_size = animation->time_size;
	unsigned int  slot_size = animation->slot_size;

	float duration = time_data[time_size-1];

	time = MAT_MAX(time,0);
	time = MAT_MIN(time,duration);

	unsigned int frame = time/duration*(float)(slot_size-1);
	unsigned int slot  = slot_data[frame]*12+bone*12;

	for (unsigned int i=0; i<12; i++) {
		pose[i] = pose_data[MAT_MIN(slot+i,pose_size-1)];
	}

	pose[12] = 0;
	pose[13] = 0;
	pose[14] = 0;
	pose[15] = 1;
}

#endif
